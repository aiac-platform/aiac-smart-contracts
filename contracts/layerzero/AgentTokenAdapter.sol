// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { OFTAdapter } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AgentTokenAdapter
/// @notice Adapter contract for existing AgentToken on Base chain
/// @dev Adapts existing AgentToken to LayerZero V2 OFT for cross-chain transfers
/// @dev Includes whitelist functionality where only whitelisted addresses can initiate cross-chain transfers
contract AgentTokenAdapter is OFTAdapter {
    /// @notice Whitelist mapping
    mapping(address => bool) public whitelist;
    
    /// @notice Whether whitelist functionality is enabled
    bool public whitelistEnabled;
    
    /// @notice Event emitted when address is added to whitelist
    event WhitelistAdded(address indexed user);
    
    /// @notice Event emitted when address is removed from whitelist
    event WhitelistRemoved(address indexed user);
    
    /// @notice Event emitted when whitelist status changes
    event WhitelistStatusChanged(bool enabled);

    /// @notice Custom errors
    error InvalidAddress(string name);
    error InvalidAmount(string name);
    error OnlyRole(string role);
    
    /// @notice Constructor
    /// @param _token Wrapped AgentToken address
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _owner Contract owner address
    /// @param _whitelistEnabled Whether to enable whitelist functionality by default
    constructor(
        address _token,
        address _lzEndpoint,
        address _owner,
        bool _whitelistEnabled
    ) OFTAdapter(_token, _lzEndpoint, _owner) Ownable(_owner) {
        whitelistEnabled = _whitelistEnabled;
    }
    
    /// @notice Override _debit function to add whitelist check
    /// @param _from Sender address
    /// @param _amountLD Amount in local decimals
    /// @param _minAmountLD Minimum amount in local decimals
    /// @param _dstEid Destination endpoint ID
    /// @return amountSentLD Amount sent in local decimals
    /// @return amountReceivedLD Amount received in local decimals
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        // Whitelist check
        if (whitelistEnabled) {
            require(whitelist[_from], "AgentTokenAdapter: sender not whitelisted");
        }
        
        // Call parent implementation
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }
    
    /// @notice Add address to whitelist
    /// @param _user Address to add
    function addToWhitelist(address _user) external onlyOwner {
        require(_user != address(0), "AgentTokenAdapter: invalid address");
        require(!whitelist[_user], "AgentTokenAdapter: already whitelisted");
        
        whitelist[_user] = true;
        emit WhitelistAdded(_user);
    }
    
    /// @notice Remove address from whitelist
    /// @param _user Address to remove
    function removeFromWhitelist(address _user) external onlyOwner {
        require(whitelist[_user], "AgentTokenAdapter: not whitelisted");
        
        whitelist[_user] = false;
        emit WhitelistRemoved(_user);
    }
    
    /// @notice Add multiple addresses to whitelist
    /// @param _users Array of addresses to add
    function addBatchToWhitelist(address[] calldata _users) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            require(user != address(0), "AgentTokenAdapter: invalid address");
            
            if (!whitelist[user]) {
                whitelist[user] = true;
                emit WhitelistAdded(user);
            }
        }
    }
    
    /// @notice Remove multiple addresses from whitelist
    /// @param _users Array of addresses to remove
    function removeBatchFromWhitelist(address[] calldata _users) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            
            if (whitelist[user]) {
                whitelist[user] = false;
                emit WhitelistRemoved(user);
            }
        }
    }
    
    /// @notice Set whitelist functionality status
    /// @param _enabled Whether to enable whitelist
    function setWhitelistEnabled(bool _enabled) external onlyOwner {
        whitelistEnabled = _enabled;
        emit WhitelistStatusChanged(_enabled);
    }
    
    /// @notice Check if address is whitelisted
    /// @param _user Address to check
    /// @return Whether address is whitelisted
    function isWhitelisted(address _user) external view returns (bool) {
        return whitelist[_user];
    }
} 