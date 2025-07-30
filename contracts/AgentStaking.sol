// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAgentStaking.sol";

/// @title AgentStaking
/// @notice Agent staking contract with three-state management and epoch-based unlocking
/// @dev Manages AgentToken staking operations with delayed update pattern for efficient batch processing
contract AgentStaking is Initializable, OwnableUpgradeable, IAgentStaking {
    using SafeERC20 for IERC20;
    
    /// @notice AgentToken contract instance
    IERC20 public agentToken;
    /// @notice Oracle address responsible for epoch operations
    address public oracleAddress;

    /// @notice Whether stake is enabled
    bool public enableStake;
    /// @notice Whether unstake is enabled
    bool public enableUnstake;
    /// @notice Whether restake is enabled
    bool public enableRestake;
    /// @notice Whether withdrawal is enabled
    bool public enableWithdraw;

    /// @notice User staking states mapping
    mapping(address => UserStakingState) private _userStakingStates;
    
    /// @notice Current epoch index
    uint256 public currentEpoch;
    
    /// @notice Records the epoch when user last unstaked
    mapping(address => uint256) private userLastUnstakeEpoch;
    
    /// @notice Check if caller is Oracle address
    modifier onlyOracle() {
        if (msg.sender != oracleAddress) revert OnlyRole("oracle");
        _;
    }
    
    /// @notice Disable default constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice Initialize the contract
    /// @param _agentToken AgentToken contract address
    /// @param _oracle Oracle address for epoch operations
    /// @param _owner Contract owner address
    function initialize(
        address _agentToken,
        address _oracle,
        address _owner
    ) external initializer {
        __Ownable_init();
        _transferOwnership(_owner);
        
        if (_agentToken == address(0)) revert InvalidAddress("agentToken");
        if (_oracle == address(0)) revert InvalidAddress("oracle");
        
        agentToken = IERC20(_agentToken);
        oracleAddress = _oracle;
        currentEpoch = 1; // Start from epoch 1
    }
    
    /// @notice Set Oracle address
    /// @param _oracle New Oracle address
    function setOracleAddress(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert InvalidAddress("oracle");
        oracleAddress = _oracle;
    }

    /// @notice Set whether stake is enabled
    /// @param enable Whether stake is enabled
    function setEnableStake(bool enable) external onlyOwner {
        enableStake = enable;
    }

    /// @notice Set whether unstake is enabled
    /// @param enable Whether unstake is enabled
    function setEnableUnstake(bool enable) external onlyOwner {
        enableUnstake = enable;
    }

    /// @notice Set whether restake is enabled
    /// @param enable Whether restake is enabled
    function setEnableRestake(bool enable) external onlyOwner {
        enableRestake = enable;
    }

    /// @notice Set whether withdrawal is enabled
    /// @param enable Whether withdrawal is enabled
    function setEnableWithdraw(bool enable) external onlyOwner {
        enableWithdraw = enable;
    }
    
    /// @inheritdoc IAgentStaking
    function stake(uint256 amount) external override {
        if (!enableStake) revert StakeDisabled();
        if (amount == 0) revert InvalidAmount("amount");
        
        // Transfer AgentToken from user
        agentToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update user staking state first
        _processUnstakedIfEligible(msg.sender);
        
        // Add to staked amount
        _userStakingStates[msg.sender].stakedAmount += amount;
        
        emit Staked(address(agentToken), msg.sender, currentEpoch, amount);
    }
    
    /// @inheritdoc IAgentStaking
    function unstake(uint256 amount) external override {
        if (!enableUnstake) revert UnstakeDisabled();
        if (amount == 0) revert InvalidAmount("amount");
        
        // Update user staking state first
        _processUnstakedIfEligible(msg.sender);
        
        UserStakingState storage state = _userStakingStates[msg.sender];
        
        if (amount > state.stakedAmount) revert InvalidAmount("amount exceeds staked");
        
        // Move from staked to unstaked
        state.stakedAmount -= amount;
        state.unstakedAmount += amount;
        
        // Record the epoch for this unstake request
        userLastUnstakeEpoch[msg.sender] = currentEpoch;
        
        emit Unstaked(address(agentToken), msg.sender, currentEpoch, amount);
    }
    
    /// @inheritdoc IAgentStaking
    function restake(uint256 amount) external override {
        if (!enableRestake) revert RestakeDisabled();
        if (amount == 0) revert InvalidAmount("amount");

        // Update user staking state first
        _processUnstakedIfEligible(msg.sender);
        
        UserStakingState storage state = _userStakingStates[msg.sender];
        
        if (amount > state.unstakedAmount) revert InvalidAmount("amount exceeds unstaked");
        
        // Move from unstaked back to staked
        state.unstakedAmount -= amount;
        state.stakedAmount += amount;
        
        emit Restaked(address(agentToken), msg.sender, currentEpoch, amount);
    }
    
    /// @inheritdoc IAgentStaking
    function withdraw(uint256 amount) external override {
        if (!enableWithdraw) revert WithdrawDisabled();
        if (amount == 0) revert InvalidAmount("amount");

        // Update user staking state first
        _processUnstakedIfEligible(msg.sender);
        
        UserStakingState storage state = _userStakingStates[msg.sender];
        
        if (amount > state.withdrawableAmount) revert InvalidAmount("amount exceeds withdrawable");
        
        // Reduce withdrawable amount
        state.withdrawableAmount -= amount;
        
        // Transfer tokens to user
        agentToken.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(address(agentToken), msg.sender, currentEpoch, amount);
    }
    
    /// @inheritdoc IAgentStaking
    function userStakingState(address user) external view override returns (UserStakingState memory) {
        UserStakingState memory state = _userStakingStates[user];
        (bool eligible, uint256 amount) = _checkUnstakedEligibility(user);
        if (eligible) {
            state.withdrawableAmount += amount;
            state.unstakedAmount -= amount;
        }
        
        return state;
    }

    /// @notice Get raw user staking state
    /// @param user User address
    /// @return Raw staking state
    function rawUserStakingState(address user) external view returns (UserStakingState memory) {
        return _userStakingStates[user];
    }
    
    /// @inheritdoc IAgentStaking
    function advanceEpoch(uint256 expectedCurrentEpoch) external override onlyOracle {
        if (currentEpoch != expectedCurrentEpoch) {
            revert UnexpectedEpochState(currentEpoch, expectedCurrentEpoch);
        }
        
        uint256 previousEpoch = currentEpoch;
        currentEpoch += 1;
        
        emit EpochAdvanced(address(agentToken), previousEpoch, currentEpoch, block.timestamp);
    }
    
    /// @notice Check if user has unstaked amount eligible for withdrawal
    /// @param user User address
    /// @return eligible True if user has unstaked amount from previous epochs
    /// @return amount Amount eligible for withdrawal
    function _checkUnstakedEligibility(address user) internal view returns (bool eligible, uint256 amount) {
        UserStakingState memory state = _userStakingStates[user];
        
        if (userLastUnstakeEpoch[user] < currentEpoch && state.unstakedAmount > 0) {
            return (true, state.unstakedAmount);
        }
        
        return (false, 0);
    }
    
    /// @notice Process user's unstaked amount if eligible for withdrawal
    /// @param user User address to process
    function _processUnstakedIfEligible(address user) internal {
        (bool eligible, uint256 amount) = _checkUnstakedEligibility(user);
        if (!eligible) return;

        UserStakingState storage state = _userStakingStates[user];
        state.withdrawableAmount += amount;
        state.unstakedAmount -= amount;
    }



    /// @notice OpenZeppelin storage space reservation for future version upgrades
    uint256[50] private __gap;
} 