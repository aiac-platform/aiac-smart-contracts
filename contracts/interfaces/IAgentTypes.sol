// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAgentTypes
/// @notice Define shared types, structs and errors in the Agent system
/// @dev Imported by other interfaces and contracts to ensure consistency of type definitions
interface IAgentTypes {
    /// Common errors
    /// @notice Invalid address
    /// @param name Address name/type
    error InvalidAddress(string name);
    
    /// @notice Invalid amount
    /// @param name Amount name/type
    error InvalidAmount(string name);
    
    /// @notice Only specific role can call
    /// @param role Required role name
    error OnlyRole(string role);

    /// @notice Unlock strategy type
    enum UnlockStrategyType {
        TimeBased,
        OracleBased
    }

    /// @notice Token unlock record structure
    /// @param unlockTime Unlock time
    /// @param seedingAmount Seed stage unlock amount
    /// @param accelerationAmount Acceleration stage unlock amount
    struct UnlockRecord {
        uint256 unlockTime;
        uint256 seedingAmount;
        uint256 accelerationAmount;
    }
} 