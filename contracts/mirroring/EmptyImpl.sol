// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title EmptyImpl
/// @notice Empty implementation contract, used as placeholder for proxy deployment
/// @dev This contract has no state variables and business logic, only used for CREATE2 address reservation
contract EmptyImpl is Initializable {
    
    /// @notice Empty initialization function
    /// @dev Does nothing, only used to satisfy proxy contract initialization requirements
    function initialize() external initializer {
        // Empty implementation - does nothing
    }
} 