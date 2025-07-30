// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentTypes.sol";

interface IAgentFactory {
    error NotAuthorized();
    error InvalidImplementation();
    error RouterNotSet();
    error InvalidUnlockStrategy();

    /// @notice Event emitted when Agent token and Agent investment pool are created
    /// @param creator Creator address
    /// @param agentToken Agent token address
    /// @param agentPool Agent investment pool address
    /// @param agentTokenName Agent token name
    /// @param agentTokenSymbol Agent token symbol
    /// @param unlockStrategy Unlock strategy type
    /// @param initialInvestor Initial investor address
    /// @param ethIn Initial investment amount
    /// @param agentTokenOut Initial Agent token amount
    /// @param nonce Unique identifier
    event AgentCreated(
        address indexed creator,
        address indexed agentToken,
        address indexed agentPool,
        string agentTokenName,
        string agentTokenSymbol,
        IAgentTypes.UnlockStrategyType unlockStrategy,
        address initialInvestor,
        uint256 ethIn,
        uint256 agentTokenOut,
        uint256 nonce
    );

    /// @notice Event emitted when token implementation contract is upgraded
    /// @param oldImplementation Old implementation contract address
    /// @param newImplementation New implementation contract address
    event TokenImplementationUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @notice Event emitted when pool implementation contract is upgraded
    /// @param oldImplementation Old implementation contract address
    /// @param newImplementation New implementation contract address
    event PoolImplementationUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @notice Initialize AgentFactory contract
    /// @param _tokenImplementation Agent token implementation contract address
    /// @param _poolImplementation Agent investment pool implementation contract address
    /// @param _timeBasedUnlockStrategyImplementation Time-based unlock strategy implementation contract address
    /// @param _oracleBasedUnlockStrategyImplementation Oracle-based unlock strategy implementation contract address
    /// @param _agentConfig Agent configuration contract address
    /// @param _router Router contract address
    /// @param _owner Contract owner address
    function initialize(
        address _tokenImplementation,
        address _poolImplementation,
        address _timeBasedUnlockStrategyImplementation,
        address _oracleBasedUnlockStrategyImplementation,
        address _agentConfig,
        address _router,
        address _owner
    ) external;

    /// @notice Upgrade AgentToken implementation contract
    /// @param newImplementation New implementation contract address
    function upgradeTokenImplementation(address newImplementation) external;

    /// @notice Upgrade AgentPool implementation contract
    /// @param newImplementation New implementation contract address
    function upgradePoolImplementation(address newImplementation) external;

    /// @notice Create Agent token and Agent investment pool
    /// @param creator Creator address
    /// @param name Agent token name
    /// @param symbol Agent token symbol
    /// @param initialInvestor Initial investor address
    /// @param nonce Unique identifier
    /// @return agentToken Agent token address
    /// @return agentPool Agent investment pool address
    function createAgentTokenAndPool(
        address creator,
        string memory name,
        string memory symbol,
        address initialInvestor,
        uint256 nonce
    ) external payable returns (address agentToken, address agentPool);

    /// @notice Get router contract address
    /// @return Router contract address
    function router() external view returns (address);
} 