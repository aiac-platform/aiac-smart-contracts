// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAgentAirdropTypes.sol";
import "./interfaces/IAgentAirdropRouter.sol";
import "./interfaces/IAgentAirdropCampaign.sol";

/// @title AgentAirdropRouter
/// @notice Responsible for managing AgentToken airdrop functionality, supporting multiple airdrop campaigns
/// @dev Manages multiple airdrop campaigns and forwards operations to corresponding airdrop campaign contracts
contract AgentAirdropRouter is Initializable, OwnableUpgradeable, IAgentAirdropRouter {
    using SafeERC20 for IERC20;
    using ClonesUpgradeable for address;

    /// @notice List of airdrop campaign contract addresses
    address[] private _campaignAddresses;

    /// @notice Airdrop campaign contract implementation address
    address private _implementation;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentAirdropRouter
    function initialize(address _owner, address implementation) external initializer {
        __Ownable_init();
        _transferOwnership(_owner);

        if (implementation == address(0)) revert IAgentAirdropTypes.InvalidTokenAddress();
        _implementation = implementation;
    }

    /// @inheritdoc IAgentAirdropRouter
    function createCampaign(
        bytes32 merkleRoot,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    ) external onlyOwner returns (uint256 campaignId, address campaignAddress) {
        // Verify parameters
        if (merkleRoot == bytes32(0)) revert IAgentAirdropTypes.InvalidMerkleRoot();
        if (token == address(0)) revert IAgentAirdropTypes.InvalidTokenAddress();
        if (startTime >= endTime) revert IAgentAirdropTypes.InvalidTimeSettings();
        if (totalAmount == 0) revert IAgentAirdropTypes.InvalidAmount();

        // Create new airdrop campaign contract
        campaignAddress = _implementation.clone();
        
        // Transfer tokens to contract first
        IERC20(token).safeTransferFrom(msg.sender, campaignAddress, totalAmount);

        // Initialize airdrop campaign contract
        IAgentAirdropCampaign(campaignAddress).initialize(
            address(this),
            merkleRoot,
            token,
            startTime,
            endTime,
            totalAmount
        );

        // Add to airdrop campaign list
        _campaignAddresses.push(campaignAddress);
        campaignId = _campaignAddresses.length - 1;

        emit CampaignCreated(
            campaignId,
            campaignAddress,
            merkleRoot,
            token,
            startTime,
            endTime,
            totalAmount
        );

        return (campaignId, campaignAddress);
    }

    /// @inheritdoc IAgentAirdropRouter
    function setTimeSettings(
        uint256 campaignId,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Update airdrop campaign time settings
        IAgentAirdropCampaign(campaignAddress).setTimeSettings(
            startTime,
            endTime
        );
        
        emit TimeSettingsUpdated(
            campaignId,
            startTime,
            endTime
        );
    }

    /// @inheritdoc IAgentAirdropRouter
    function setActive(uint256 campaignId, bool active) external onlyOwner {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Update airdrop campaign activation status
        IAgentAirdropCampaign(campaignAddress).setActive(active);
        
        emit ActiveStatusUpdated(
            campaignId,
            active
        );
    }

    /// @inheritdoc IAgentAirdropRouter
    function getStatus(uint256 campaignId) external view returns (IAgentAirdropTypes.CampaignStatus) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Get airdrop campaign status
        return IAgentAirdropCampaign(campaignAddress).getStatus();
    }

    /// @inheritdoc IAgentAirdropRouter
    function claim(
        uint256 campaignId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's claim function
        IAgentAirdropCampaign(campaignAddress).claim(
            account,
            amount,
            merkleProof
        );
    }

    /// @inheritdoc IAgentAirdropRouter
    function batchClaim(
        uint256[] calldata campaignIds,
        address account,
        uint256[] calldata amounts,
        bytes32[][] calldata merkleProofs
    ) external {
        // Verify parameters
        if (campaignIds.length != amounts.length || campaignIds.length != merkleProofs.length) 
            revert IAgentAirdropTypes.InvalidAmount();
        
        // Batch claim
        for (uint256 i = 0; i < campaignIds.length; i++) {
            if (campaignIds[i] >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
            
            address campaignAddress = _campaignAddresses[campaignIds[i]];
            
            // Call airdrop campaign contract's claim function
            IAgentAirdropCampaign(campaignAddress).claim(
                account,
                amounts[i],
                merkleProofs[i]
            );
        }
    }

    /// @inheritdoc IAgentAirdropRouter
    function checkClaimableAmount(
        uint256 campaignId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's query function
        return IAgentAirdropCampaign(campaignAddress).checkClaimableAmount(
            account,
            amount,
            merkleProof
        );
    }

    /// @inheritdoc IAgentAirdropRouter
    function hasClaimed(uint256 campaignId, address account) external view returns (bool) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's query function
        return IAgentAirdropCampaign(campaignAddress).hasClaimed(account);
    }

    /// @inheritdoc IAgentAirdropRouter
    function withdrawReversed(uint256 campaignId, address recipient) external onlyOwner {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        if (recipient == address(0)) revert IAgentAirdropTypes.InvalidRecipientAddress();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's withdraw function
        IAgentAirdropCampaign(campaignAddress).withdrawReversed(recipient);
    }

    /// @inheritdoc IAgentAirdropRouter
    function addTokens(uint256 campaignId, uint256 additionalAmount) external onlyOwner {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        if (additionalAmount == 0) revert IAgentAirdropTypes.InvalidAmount();
        
        address campaignAddress = _campaignAddresses[campaignId];
        IAgentAirdropTypes.Campaign memory campaign = IAgentAirdropCampaign(campaignAddress).getCampaign();
        
        // Transfer additional tokens
        IERC20(campaign.token).safeTransferFrom(msg.sender, campaignAddress, additionalAmount);
        
        // Call airdrop campaign contract's add tokens function
        IAgentAirdropCampaign(campaignAddress).addTokens(additionalAmount);
    }

    /// @inheritdoc IAgentAirdropRouter
    function getCampaignAddress(uint256 campaignId) external view returns (address) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        return _campaignAddresses[campaignId];
    }

    /// @inheritdoc IAgentAirdropRouter
    function getCampaign(uint256 campaignId) external view returns (IAgentAirdropTypes.Campaign memory) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's query function
        return IAgentAirdropCampaign(campaignAddress).getCampaign();
    }

    /// @inheritdoc IAgentAirdropRouter
    function getCampaignCount() external view returns (uint256) {
        return _campaignAddresses.length;
    }

    /// @inheritdoc IAgentAirdropRouter
    function getRemainingAmount(uint256 campaignId) external view returns (uint256) {
        if (campaignId >= _campaignAddresses.length) revert IAgentAirdropTypes.InvalidCampaignId();
        
        address campaignAddress = _campaignAddresses[campaignId];
        
        // Call airdrop campaign contract's query function
        return IAgentAirdropCampaign(campaignAddress).getRemainingAmount();
    }

    /// @inheritdoc IAgentAirdropRouter
    function setImplementation(address implementation) external onlyOwner {
        if (implementation == address(0)) revert IAgentAirdropTypes.InvalidTokenAddress();
        _implementation = implementation;
    }

    /// @dev OpenZeppelin storage space reservation for future version upgrades to add new storage variables
    uint256[50] private __gap;
} 