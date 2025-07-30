// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../layerzero/AgentTokenOFT.sol";


/// @title AgentTokenOFTFactory
/// @notice Factory contract on BSC chain for multiple address reservation and CREATE2 deployment
/// @dev Implements multiple reservation mechanism, matches TokenBeacon address through reservation
contract AgentTokenOFTFactory is Initializable, OwnableUpgradeable {
    /// @notice TokenBeacon contract address (obtained through reservation matching)
    address public tokenBeacon;
    
    /// @notice Proxy contract deployment event
    event AgentTokenOFTCreated(
        address indexed proxy,
        bytes32 indexed salt,
        address indexed creator
    );
    
    /// @notice TokenBeacon address setting event
    event TokenBeaconSet(
        address indexed beacon,
        address indexed setter
    );
    
    /// @notice Empty proxy contract deployment event (for reservation)
    event EmptyProxyDeployed(
        address indexed proxy,
        uint256 indexed nonce,
        address indexed deployer
    );
    
    /// @notice Error: Invalid parameter
    error InvalidParameter(string param);
    
    /// @notice Error: TokenBeacon not set
    error TokenBeaconNotSet();
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice Initialize Factory contract
    /// @param _factoryOwner Contract owner address
    function initialize(
        address _factoryOwner
    ) external initializer {
        __Ownable_init();
        _transferOwnership(_factoryOwner);
    }
    
    /// @notice Deploy token beacon contract for a target address
    /// @param attempCount max attemp deployment count
    /// @param targetTokenBeacon Target TokenBeacon address
    /// @param agentTokenOFTImpl AgentTokenOFT implementation contract address
    /// @param beaconOwner Beacon owner address
    function deployTokenBeacon(
        uint256 attempCount,
        address targetTokenBeacon,
        address agentTokenOFTImpl,
        address beaconOwner
    ) external onlyOwner {
        if (agentTokenOFTImpl == address(0)) revert InvalidParameter("agentTokenOFTImpl");
        if (targetTokenBeacon == address(0)) revert InvalidParameter("targetTokenBeacon");
        if (attempCount == 0) revert InvalidParameter("beaconProxyCount");
        if (beaconOwner == address(0)) revert InvalidParameter("beaconOwner");

        for (uint256 i = 0; i < attempCount; i++) {
            // Use CREATE to deploy UpgradeableBeacon, address depends on Factory address + nonce
            address proxy = address(new UpgradeableBeacon(
                agentTokenOFTImpl,  // Directly use AgentTokenOFT implementation contract
                beaconOwner
            ));
            
            // Check if matches target address
            if (proxy == targetTokenBeacon) {
                // Found matching address, set as TokenBeacon
                tokenBeacon = proxy;
                emit TokenBeaconSet(proxy, address(this));
                emit EmptyProxyDeployed(proxy, i, address(this));
                return;
            }
            else {
                emit EmptyProxyDeployed(proxy, i, address(this));
            }
        }
        
        // If no matching address found, throw error
        revert("TokenBeacon address not found in range");
    }
    
    /// @notice Deploy BeaconProxy proxy contract using CREATE2
    /// @param targetTokenAddress Target Token address
    /// @param salt CREATE2 salt value
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param tokenOwner Token owner address
    /// @param whitelistEnabled Whether to enable whitelist
    /// @return proxy Deployed proxy contract address
    function createAgentTokenOFT(
        address targetTokenAddress,
        bytes32 salt,
        string memory name,
        string memory symbol,
        address tokenOwner,
        bool whitelistEnabled
    ) external onlyOwner returns (address proxy) {
        if (tokenBeacon == address(0)) revert TokenBeaconNotSet();
        if (tokenOwner == address(0)) revert InvalidParameter("tokenOwner");
        
        // Deploy BeaconProxy using CREATE2
        proxy = address(new BeaconProxy{salt: salt}(
            tokenBeacon,  // Use TokenBeacon from reservation matching or initialization setting
            ""
        ));

        if (proxy != targetTokenAddress) {
            revert("targetTokenAddress not match");
        }

        // Initialize AgentTokenOFT contract
        AgentTokenOFT(proxy).initialize(
            name,
            symbol,
            tokenOwner,
            whitelistEnabled
        );
        
        // Emit event
        emit AgentTokenOFTCreated(proxy, salt, msg.sender);
        return proxy;
    }
    
    /// @dev OpenZeppelin storage gap for future upgrades
    uint256[50] private __gap;
} 