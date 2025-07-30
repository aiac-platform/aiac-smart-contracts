// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAgentConfig.sol";
import "./interfaces/IAgentToken.sol";
import "./interfaces/IUnlockStrategy.sol";

/// @title AgentToken
/// @notice Agent token contract, implements token locking and linear unlocking mechanism
/// @dev Inherits from ERC20Upgradeable, implements IAgentToken interface
contract AgentToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, IAgentToken {
    /// @dev Records the amount of tokens locked by users
    struct LockedAmount {
        uint256 seedingLockedAmount;
        uint256 accelerationLockedAmount;
    }

    /// @dev Investment pool contract address
    address public agentPool;
    
    /// @dev Unlock strategy contract
    IUnlockStrategy public unlockStrategy;

    /// @dev User locked token amount mapping
    mapping(address => LockedAmount) private _originLockedAmounts;

    /// @dev Check if the caller is the investment pool contract
    modifier onlyPool() {
        if (msg.sender != agentPool) revert NotAuthorized();
        _;
    }

    // Constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentToken
    function initialize(
        string memory _name,
        string memory _symbol,
        address _agentConfig,
        address _agentPool,
        address _unlockStrategy,
        address _owner
    ) public initializer {
        if (_agentPool == address(0)) revert InvalidPoolAddress();

        __ERC20_init(_name, _symbol);
        __Ownable_init();
        _transferOwnership(_owner);

        agentPool = _agentPool;

        if (_unlockStrategy == address(0)) revert InvalidUnlockStrategy();
        unlockStrategy = IUnlockStrategy(_unlockStrategy);

        uint256 initialSupply = IAgentConfig(_agentConfig).getAgentTokenTotalSupply();
        _mint(address(agentPool), initialSupply);
    }

    /// @notice Set unlock strategy contract
    /// @param _unlockStrategy Unlock strategy contract address
    function setUnlockStrategy(address _unlockStrategy) external onlyOwner {
        if (_unlockStrategy == address(0)) revert InvalidUnlockStrategy();
        if (unlockStrategy.isUnlockStarted()) revert UnlockAlreadyStarted();
        unlockStrategy = IUnlockStrategy(_unlockStrategy);
    }

    /// @inheritdoc IAgentToken
    function lockedBalanceOf(address addr) public view returns (uint256) {
        if (_originLockedAmounts[addr].seedingLockedAmount == 0 && _originLockedAmounts[addr].accelerationLockedAmount == 0) {
            return 0;
        }

        if (address(unlockStrategy) == address(0)) {
            // If no unlock strategy is set, all tokens are locked
            return _originLockedAmounts[addr].seedingLockedAmount + _originLockedAmounts[addr].accelerationLockedAmount;
        }
        
        return unlockStrategy.calculateLockedBalance(
            _originLockedAmounts[addr].seedingLockedAmount,
            _originLockedAmounts[addr].accelerationLockedAmount
        );
    }

    /// @inheritdoc IAgentToken
    function unlockedBalanceOf(address addr) public view returns (uint256) {
        return super.balanceOf(addr) - lockedBalanceOf(addr);
    }

    /// @dev Override ERC20Upgradeable's balanceOf implementation, returns unlocked token amount
    /// @param account Address to query
    /// @return Unlocked token amount
    function balanceOf(address account) public view virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
        return unlockedBalanceOf(account);
    }

    /// @inheritdoc IAgentToken
    function transferAndLockSeeding(address to, uint256 amount) external onlyPool {
        if (to == address(0)) revert InvalidRecipientAddress();
        
        // Check if unlock has started
        if (address(unlockStrategy) != address(0) && unlockStrategy.isUnlockStarted()) {
            revert UnlockAlreadyStarted();
        }
        
        _transfer(msg.sender, to, amount);
        _originLockedAmounts[to].seedingLockedAmount += amount;
    }

    /// @inheritdoc IAgentToken
    function transferAndLockAcceleration(address to, uint256 amount) external onlyPool {
        if (to == address(0)) revert InvalidRecipientAddress();
        
        // Check if unlock has started
        if (address(unlockStrategy) != address(0) && unlockStrategy.isUnlockStarted()) {
            revert UnlockAlreadyStarted();
        }
        
        _transfer(msg.sender, to, amount);
        _originLockedAmounts[to].accelerationLockedAmount += amount;
    }

    /// @inheritdoc IAgentToken
    function refundFrom(address from) external onlyPool {
        // Check if unlock has started
        if (address(unlockStrategy) != address(0) && unlockStrategy.isUnlockStarted()) {
            revert UnlockAlreadyStarted();
        }
        
        _originLockedAmounts[from].seedingLockedAmount = 0;
        _originLockedAmounts[from].accelerationLockedAmount = 0;
        _transfer(from, address(agentPool), super.balanceOf(from));
    }

    /// @inheritdoc IAgentToken
    function startUnlock() external onlyPool {
        if (address(unlockStrategy) == address(0)) {
            revert NotAuthorized();
        }
        
        unlockStrategy.startUnlock();
    }

    /// @inheritdoc IAgentToken
    function nextUnlockTime() external view returns (uint256) {
        if (address(unlockStrategy) == address(0)) {
            return 0;
        }
        
        return unlockStrategy.getNextUnlockTime();
    }

    /// @inheritdoc IAgentToken
    function nextUnlockAmount(address addr) external view returns (uint256) {
        if (address(unlockStrategy) == address(0)) {
            return 0;
        }
        
        return unlockStrategy.getNextUnlockAmount(
            _originLockedAmounts[addr].seedingLockedAmount,
            _originLockedAmounts[addr].accelerationLockedAmount
        );
    }

    /// @inheritdoc IAgentToken
    function getUnlockRecordsFor(address addr) external view returns (UnlockRecord[] memory) {
        if (address(unlockStrategy) == address(0)) {
            return new UnlockRecord[](0);
        }
        
        return unlockStrategy.getUnlockRecords(
            _originLockedAmounts[addr].seedingLockedAmount,
            _originLockedAmounts[addr].accelerationLockedAmount
        );
    }

    /// @notice Get the original locked amount for the specified address
    /// @param addr Address to query
    /// @return seedingLocked Seed round locked amount
    /// @return accelerationLocked Acceleration round locked amount 
    function getOriginLockedAmounts(address addr) external view returns (uint256 seedingLocked, uint256 accelerationLocked) {
        seedingLocked = _originLockedAmounts[addr].seedingLockedAmount;
        accelerationLocked = _originLockedAmounts[addr].accelerationLockedAmount;
    }

    /// @dev Override transfer function, add locked token check
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Logic to prevent transfer of locked tokens
        if (from != address(0) && to != address(0)) {
            uint256 availableBalance = super.balanceOf(from) - lockedBalanceOf(from);
            if (amount > availableBalance) revert UnlockedBalanceNotEnough();
        }

        // Call parent contract's transfer function
        super._transfer(from, to, amount);
    }

    /// @dev OpenZeppelin storage space reservation for future version upgrades to add new storage variables
    uint256[50] private __gap;
}
