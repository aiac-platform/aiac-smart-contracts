// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentTypes.sol";
/// @title IUnlockStrategy
/// @notice Define the interface for token unlock strategy
/// @dev All unlock strategy implementations must follow this interface
interface IUnlockStrategy is IAgentTypes {
    // Unlock strategy related errors
    /// @notice Unlock has already started
    error UnlockAlreadyStarted();
    
    /// @notice Unlock has not started yet
    error UnlockNotStarted();

    /// @notice Unlock time is invalid
    error InvalidUnlockTime();
    
    /// @notice Unlock ratio is too high
    /// @param stage Unlock stage that exceeds the limit
    error UnlockRatioTooHigh(string stage);

    /// @notice Calculate locked token amount for specified address
    /// @param seedingLockedAmount User's seed stage locked amount
    /// @param accelerationLockedAmount User's acceleration stage locked amount
    /// @return Current total locked token amount
    function calculateLockedBalance(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view returns (uint256);
    
    /// @notice Get next unlock time
    /// @return Next unlock timestamp, returns 0 if there is no next unlock
    function getNextUnlockTime() external view returns (uint256);
    
    /// @notice Get next unlock amount
    /// @param seedingLockedAmount User's seed stage locked amount
    /// @param accelerationLockedAmount User's acceleration stage locked amount
    /// @return Next unlock token amount
    function getNextUnlockAmount(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view returns (uint256);
    
    /// @notice Get unlock records
    /// @param seedingLockedAmount User's seed stage locked amount
    /// @param accelerationLockedAmount User's acceleration stage locked amount
    /// @return Array of unlock records
    function getUnlockRecords(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view returns (UnlockRecord[] memory);
    
    /// @notice Start unlock process
    function startUnlock() external;
    
    /// @notice Check if unlock has started
    /// @return Whether unlock has started
    function isUnlockStarted() external view returns (bool);
} 