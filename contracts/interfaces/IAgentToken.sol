// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IAgentTypes.sol";

/// @title IAgentToken
/// @notice Agent token interface, defining token locking and unlocking mechanism
/// @dev Inherits from IERC20Upgradeable, implementing token locking and linear unlocking functionality
interface IAgentToken is IERC20Upgradeable, IAgentTypes {
    error NotAuthorized();
    error InvalidPoolAddress();
    error InvalidUnlockStrategy();
    error InvalidRecipientAddress();
    error UnlockAlreadyStarted();
    error UnlockedBalanceNotEnough();

    /// @notice Initialize token contract
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _agentConfig Configuration contract address
    /// @param _agentPool Investment pool contract address
    /// @param _unlockStrategy Unlock strategy contract address
    /// @param _owner Contract owner address
    function initialize(
        string memory _name,
        string memory _symbol,
        address _agentConfig,
        address _agentPool,
        address _unlockStrategy,
        address _owner
    ) external;

    /// @notice Get investment pool contract address
    /// @return Investment pool contract address
    function agentPool() external view returns (address);

    /// @notice Get locked token amount for specified address
    /// @param addr Address to query
    /// @return Locked token amount
    function lockedBalanceOf(address addr) external view returns (uint256);

    /// @notice Get unlocked token amount for specified address
    /// @param addr Address to query
    /// @return Unlocked token amount
    function unlockedBalanceOf(address addr) external view returns (uint256);

    /// @notice Transfer and lock seeding stage tokens
    /// @param to Recipient address
    /// @param amount Token amount
    function transferAndLockSeeding(address to, uint256 amount) external;

    /// @notice Transfer and lock acceleration stage tokens
    /// @param to Recipient address
    /// @param amount Token amount
    function transferAndLockAcceleration(address to, uint256 amount) external;

    /// @notice Refund tokens from specified address back to investment pool
    /// @param from Address to refund tokens from
    function refundFrom(address from) external;

    /// @notice Start token unlock
    function startUnlock() external;

    /// @notice Get next unlock time
    /// @return Next unlock timestamp
    function nextUnlockTime() external view returns (uint256);

    /// @notice Get unlock amount for specified address in next unlock period
    /// @param addr Address to query
    /// @return Unlock amount in next period
    function nextUnlockAmount(address addr) external view returns (uint256);

    /// @notice Get all unlock records for specified address
    /// @param addr Address to query
    /// @return Array of unlock records
    function getUnlockRecordsFor(address addr) external view returns (UnlockRecord[] memory);
}
