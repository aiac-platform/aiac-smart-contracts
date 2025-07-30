// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "./external/IWETH.sol";

import "./interfaces/IAgentRouter.sol";
import "./interfaces/IAgentFactory.sol";
import "./interfaces/IAgentPool.sol";
import "./interfaces/IAgentToken.sol";
import "./interfaces/IAgentConfig.sol";

/// @title AgentRouter
/// @notice Agent router contract responsible for managing staking, investment and refund operations
/// @dev Implements IAgentRouter interface using upgradeable proxy pattern
contract AgentRouter is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IAgentRouter {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @dev Agent configuration contract instance
    IAgentConfig internal _agentConfigContract;
    /// @dev Agent factory contract instance
    IAgentFactory internal _factoryContract;

    /// @dev User staking amount mapping
    mapping(address => uint256) public stakes;
    /// @dev Agent token to investment pool mapping
    mapping(address => IAgentPool) internal _poolForToken;
    /// @dev Investment pool to Agent token mapping
    mapping(address => IAgentToken) internal _tokenForPool;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentRouter
    function initialize(
        address _agentConfig,
        address _owner
    ) public initializer override {
        __ReentrancyGuard_init();
        __Ownable_init();
        _transferOwnership(_owner);

        _agentConfigContract = IAgentConfig(_agentConfig);
    }

    /// @inheritdoc IAgentRouter
    function factory() external view override returns (address) {
        return address(_factoryContract);
    }

    /// @inheritdoc IAgentRouter
    function setFactory(address _factory) external onlyOwner override {
        _factoryContract = IAgentFactory(_factory);
    }

    /// @inheritdoc IAgentRouter
    function agentConfig() external view override returns (address) {
        return address(_agentConfigContract);
    }

    /// @inheritdoc IAgentRouter
    function stakeReadyFor(address staker) public view override returns (bool) {
        if (staker == address(0)) revert InvalidStaker();
        return requireStakeFor(staker) == 0;
    }

    /// @inheritdoc IAgentRouter
    function requireStakeFor(address staker) public view override returns (uint256) {
        uint256 stakeAmount = _agentConfigContract.getStakeAmount();
        if (staker == address(0)) revert InvalidStaker();
        if (stakes[staker] >= stakeAmount) {
            return 0;
        }
        else {
            return stakeAmount - stakes[staker];
        }
    }

    /// @inheritdoc IAgentRouter
    function stake() external payable override {
        uint256 requireStakeAmount = requireStakeFor(msg.sender);
        if (requireStakeAmount == 0) revert AlreadyStaked();
        if (msg.value != requireStakeAmount) revert InvalidStakeAmount();
        
        uint256 stakeAmount = msg.value;
        stakes[msg.sender] += stakeAmount;
        
        emit Staked(msg.sender, stakeAmount, stakes[msg.sender]);
    }

    /// @inheritdoc IAgentRouter
    function unstake() external override nonReentrant {
        uint256 amount = stakes[msg.sender];
        if (amount == 0) revert InsufficientStakeBalance();
        
        stakes[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert EthTransferFailed();
        
        emit Unstaked(msg.sender, amount);
    }

    /// @inheritdoc IAgentRouter
    function createAgentTokenAndPool(
        string memory name,
        string memory symbol,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature
    ) external returns (address agentToken, address agentPool) {
        uint256 stakeAmount = _agentConfigContract.getStakeAmount();
        if (!stakeReadyFor(msg.sender)) revert InsufficientStake();
        if (address(this).balance < stakeAmount) revert InsufficientBalance();
        stakes[msg.sender] -= stakeAmount;

        address signer = _agentConfigContract.getAgentSigner();
        if (signer != address(0)) {
            if (block.timestamp > deadline) revert SignatureExpired();
            
            // Verify signature
            if (!verifyCreateAgentSignature(msg.sender, name, symbol, nonce, deadline, signature, signer)) {
                revert InvalidSignature();
            }
        }

        (agentToken, agentPool) = _factoryContract.createAgentTokenAndPool{value: stakeAmount}(
            msg.sender, // _creator
            name,
            symbol,
            msg.sender, // _initialInvestor
            nonce
        );

        _poolForToken[agentToken] = IAgentPool(agentPool);
        _tokenForPool[agentPool] = IAgentToken(agentToken);
    }

    /// @inheritdoc IAgentRouter
    function getAmountOut(
        address agentToken,
        uint256 amountIn
    ) public view override returns (uint256) {
        if (agentToken == address(0)) revert InvalidAgentToken();

        IAgentPool pool = _poolForToken[agentToken];
        if (address(pool) == address(0)) revert PoolNotFound();

        (uint256 acceptedEthIn, uint256 agentTokenOut) = pool.getAgentTokenOut(amountIn);
        if (acceptedEthIn != amountIn) revert InvestRefused();

        return agentTokenOut;
    }

    /// @notice Verify signature for creating Agent
    /// @param creator Creator address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param nonce Random number
    /// @param deadline Signature expiration time
    /// @param signature Signature data
    /// @param expectedSigner Expected signer address
    /// @return Whether signature is valid
    function verifyCreateAgentSignature(
        address creator,
        string memory name,
        string memory symbol,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature,
        address expectedSigner
    ) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(
                creator, 
                name, 
                symbol, 
                nonce,
                deadline,
                block.chainid
            ))
        ));
        
        return _verifySignature(messageHash, signature, expectedSigner);
    }

    /// @notice Verify signature for investment
    /// @param investor Investor address
    /// @param agentToken Token address
    /// @param stage Current stage of investment pool
    /// @param deadline Signature expiration time
    /// @param signature Signature data
    /// @param expectedSigner Expected signer address
    /// @return Whether signature is valid
    function verifyInvestSignature(
        address investor,
        address agentToken,
        IAgentPool.Stage stage,
        uint256 deadline,
        bytes memory signature,
        address expectedSigner
    ) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(
                investor, 
                agentToken, 
                uint8(stage), 
                deadline,
                block.chainid
            ))
        ));
        
        return _verifySignature(messageHash, signature, expectedSigner);
    }

    /// @dev Verify signature
    /// @param messageHash Message hash
    /// @param signature Signature data
    /// @param expectedSigner Expected signer address
    /// @return Whether signature is valid
    function _verifySignature(
        bytes32 messageHash, 
        bytes memory signature, 
        address expectedSigner
    ) private pure returns (bool) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recoveredSigner = ECDSA.recover(ethSignedMessageHash, signature);
        return recoveredSigner == expectedSigner;
    }

    /// @inheritdoc IAgentRouter
    function invest(
        address agentToken,
        uint256 minAgentTokenOut,
        address recipient,
        uint256 deadline,
        bytes memory signature
    ) external payable override nonReentrant returns (uint256) {
        if (agentToken == address(0)) revert InvalidAgentToken();
        if (recipient == address(0)) revert InvalidRecipient();
        if (recipient != msg.sender) revert InvalidRecipient();

        IAgentPool pool = _poolForToken[agentToken];
        if (address(pool) == address(0)) revert PoolNotFound();

        address signer = _agentConfigContract.getAgentSigner();
        if (signer != address(0)) {
            if (block.timestamp > deadline) revert SignatureExpired();
            
            // Get current investment pool stage
            (IAgentPool.Stage stage, , ) = pool.getCurrentStage();
            
            // Verify signature
            if (!verifyInvestSignature(msg.sender, agentToken, stage, deadline, signature, signer)) {
                revert InvalidSignature();
            }
        }

        (uint256 acceptedEthIn, uint256 agentTokenOut) = pool.invest{value: msg.value}(
            minAgentTokenOut,
            recipient
        );

        if (acceptedEthIn != msg.value) revert InvestRefused();

        return agentTokenOut;
    }

    /// @inheritdoc IAgentRouter
    function refundFor(
        address agentToken,
        address recipient
    ) external view override returns (uint256) {
        if (agentToken == address(0)) revert InvalidAgentToken();
        if (recipient == address(0)) revert InvalidRecipient();

        IAgentPool pool = _poolForToken[agentToken];
        if (address(pool) == address(0)) revert PoolNotFound();

        return pool.refundFor(recipient);
    }

    /// @inheritdoc IAgentRouter
    function claimRefund(
        address agentToken,
        address recipient
    ) external override {
        if (agentToken == address(0)) revert InvalidAgentToken();
        if (recipient == address(0)) revert InvalidRecipient();

        IAgentPool pool = _poolForToken[agentToken];
        if (address(pool) == address(0)) revert PoolNotFound();

        pool.claimRefund(recipient);
    }

    /// @dev OpenZeppelin storage space reservation for future version upgrades to add new storage variables
    uint256[50] private __gap;
}
