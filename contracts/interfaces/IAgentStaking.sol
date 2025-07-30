// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentTypes.sol";

/// @title IAgentStaking
/// @notice Interface for AgentToken staking contract with three-state management and epoch-based unlocking
/// @dev Defines core functionality for staking, unstaking, restaking and withdrawal with delayed update pattern
interface IAgentStaking is IAgentTypes {
    /// @notice User staking state structure
    /// @dev Records user's staking, unstaking and withdrawal status
    struct UserStakingState {
        uint256 stakedAmount;       // Currently staked and locked amount
        uint256 unstakedAmount;     // Unstaked amount waiting for epoch advancement
        uint256 withdrawableAmount; // Amount ready for withdrawal
    }

    /// @notice Error for unexpected epoch state
    /// @param actual Current epoch in contract
    /// @param expected Expected epoch from caller
    error UnexpectedEpochState(uint256 actual, uint256 expected);
    
    /// @notice Stake operation is disabled
    error StakeDisabled();
    /// @notice Unstake operation is disabled
    error UnstakeDisabled();
    /// @notice Restake operation is disabled
    error RestakeDisabled();
    /// @notice Withdraw operation is disabled
    error WithdrawDisabled();

    /// @notice Emitted when user stakes tokens
    /// @param token Token address
    /// @param user Staking user address
    /// @param epoch Staking epoch
    /// @param amount Staking amount
    event Staked(address indexed token, address indexed user, uint256 indexed epoch, uint256 amount);
    
    /// @notice Emitted when user unstakes tokens
    /// @param token Token address
    /// @param user Unstaking user address
    /// @param epoch Unstaking epoch
    /// @param amount Unstaking amount
    event Unstaked(address indexed token, address indexed user, uint256 indexed epoch, uint256 amount);

    /// @notice Emitted when user restakes tokens
    /// @param token Token address
    /// @param user Restaking user address
    /// @param epoch Restaking epoch
    /// @param amount Restaking amount
    event Restaked(address indexed token, address indexed user, uint256 indexed epoch, uint256 amount);

    /// @notice Emitted when user withdraws tokens
    /// @param token Token address
    /// @param user Withdrawing user address
    /// @param epoch Withdrawing epoch
    /// @param amount Withdrawing amount
    event Withdrawn(address indexed token, address indexed user, uint256 indexed epoch, uint256 amount);

    /// @notice Emitted when epoch advances
    /// @param token Token address
    /// @param previousEpoch Previous epoch number
    /// @param newEpoch New current epoch number
    /// @param timestamp Block timestamp when epoch advanced
    event EpochAdvanced(address indexed token, uint256 indexed previousEpoch, uint256 indexed newEpoch, uint256 timestamp);

    /// @notice Stake AgentToken
    /// @param amount Staking amount
    function stake(uint256 amount) external;

    /// @notice Unstake AgentToken
    /// @param amount Unstaking amount
    function unstake(uint256 amount) external;

    /// @notice Restake AgentToken
    /// @param amount Restaking amount
    function restake(uint256 amount) external;

    /// @notice Withdraw unlocked AgentToken
    /// @param amount Withdrawing amount
    function withdraw(uint256 amount) external;

    /// @notice Get user staking state
    /// @param user Staking user address
    /// @return User staking state
    function userStakingState(address user) external view returns (UserStakingState memory);

    /// @notice Get current epoch
    /// @return Current epoch
    function currentEpoch() external view returns (uint256);

    /// @notice Advance epoch
    /// @param expectedCurrentEpoch Expected current epoch
    function advanceEpoch(uint256 expectedCurrentEpoch) external;
}