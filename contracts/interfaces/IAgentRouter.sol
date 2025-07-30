// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAgentRouter
/// @notice Define the interface for Agent router contract, responsible for managing staking, investment and refund operations
/// @dev Core interface implementing staking mechanism, Agent creation and investment process
interface IAgentRouter {
    error InvalidStaker();
    error InvalidAgentToken();
    error InvalidRecipient();
    error PoolNotFound();
    error InsufficientStake();
    error InsufficientBalance();
    error InvestRefused();
    error AlreadyStaked();
    error InvalidStakeAmount();
    error InsufficientStakeBalance();
    error InvalidSignature();
    error SignatureExpired();
    error EthTransferFailed();

    /// @notice Emitted when a user successfully stakes
    /// @param staker Staker address
    /// @param stakeAmount Current staking amount
    /// @param stakedAmount Total staked amount
    event Staked(
        address indexed staker,
        uint256 stakeAmount,
        uint256 stakedAmount
    );

    /// @notice Emitted when a user unstakes
    /// @param staker Staker address
    /// @param unstakeAmount Unstaked amount
    event Unstaked(
        address indexed staker,
        uint256 unstakeAmount
    );
    
    /// @notice Initialize router contract
    /// @param _agentConfig Agent configuration contract address
    /// @param _owner Contract owner address
    function initialize(
        address _agentConfig,
        address _owner
    ) external;

    /// @notice Get factory contract address
    /// @return Factory contract address
    function factory() external view returns (address);

    /// @notice Set factory contract address
    /// @param _factory New factory contract address
    function setFactory(address _factory) external;

    /// @notice Get configuration contract address
    /// @return Configuration contract address
    function agentConfig() external view returns (address);

    /// @notice Check if specified address is ready for staking
    /// @param staker Address to check
    /// @return Returns true if ready for staking
    function stakeReadyFor(address staker) external view returns (bool);

    /// @notice Get required staking amount for specified address
    /// @param staker Address to check
    /// @return Required staking amount
    function requireStakeFor(address staker) external view returns (uint256);

    /// @notice User stakes ETH
    /// @dev Staking amount should be stakeAmount
    function stake() external payable;

    /// @notice User unstakes and withdraws ETH
    function unstake() external;

    /// @notice Create new Agent token and investment pool
    /// @param name Agent token name
    /// @param symbol Agent token symbol
    /// @param nonce Unique identifier
    /// @param deadline Signature expiration time
    /// @param signature Signature data
    /// @return agentToken Agent token address
    /// @return agentPool Agent investment pool address
    function createAgentTokenAndPool(
        string memory name,
        string memory symbol,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature
    ) external returns (address agentToken, address agentPool);

    /// @notice Calculate Agent token amount obtainable from investment
    /// @param agentToken Agent token address
    /// @param ethIn Invested ETH amount
    /// @return Obtainable Agent token amount
    function getAmountOut(
        address agentToken,
        uint256 ethIn
    ) external view returns (uint256);

    /// @notice Invest ETH to get Agent tokens
    /// @param agentToken Agent token address
    /// @param minAgentTokenOut Minimum acceptable Agent token amount
    /// @param recipient Recipient address
    /// @param deadline Signature expiration time
    /// @param signature Signature data
    /// @return agentTokenOut Actual obtained Agent token amount
    function invest(
        address agentToken,
        uint256 minAgentTokenOut,
        address recipient,
        uint256 deadline,
        bytes memory signature
    ) external payable returns (uint256 agentTokenOut);
    
    /// @notice Query refundable amount
    /// @param agentToken Agent token address
    /// @param recipient Recipient address
    /// @return Refundable ETH amount
    function refundFor(
        address agentToken,
        address recipient
    ) external view returns (uint256);

    /// @notice Claim refund
    /// @param agentToken Agent token address
    /// @param recipient Recipient address
    function claimRefund(
        address agentToken,
        address recipient
    ) external;
} 