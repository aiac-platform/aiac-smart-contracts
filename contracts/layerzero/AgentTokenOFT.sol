// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

/// @title AgentTokenOFT
/// @notice Cross-chain agent token contract deployable on any EVM-compatible chain
/// @dev Based on LayerZero V2 OFT implementation for receiving cross-chain tokens from Base chain
/// @dev Supports deployment on BSC, Arbitrum, Polygon, Optimism and any EVM-compatible chains
/// @dev Includes whitelist functionality where only whitelisted addresses can initiate cross-chain transfers
contract AgentTokenOFT is OFTUpgradeable {
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    /// @notice initialize function
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _owner Owner address
    /// @param _whitelistEnabled Whether whitelist is enabled
    function initialize(
        string memory _name,
        string memory _symbol,
        address _owner,
        bool _whitelistEnabled
    ) external initializer {
        __OFT_init(_name, _symbol, _owner);
        __Ownable_init();
        _transferOwnership(_owner);
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
            require(whitelist[_from], "AgentTokenOFT: sender not whitelisted");
        }
        
        // Call parent implementation
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }
    
    /// @notice Add address to whitelist
    /// @param _user Address to add
    function addToWhitelist(address _user) external onlyOwner {
        require(_user != address(0), "AgentTokenOFT: invalid address");
        require(!whitelist[_user], "AgentTokenOFT: already whitelisted");
        
        whitelist[_user] = true;
        emit WhitelistAdded(_user);
    }
    
    /// @notice Remove address from whitelist
    /// @param _user Address to remove
    function removeFromWhitelist(address _user) external onlyOwner {
        require(whitelist[_user], "AgentTokenOFT: not whitelisted");
        
        whitelist[_user] = false;
        emit WhitelistRemoved(_user);
    }
    
    /// @notice Add multiple addresses to whitelist
    /// @param _users Array of addresses to add
    function addBatchToWhitelist(address[] calldata _users) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            require(user != address(0), "AgentTokenOFT: invalid address");
            
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