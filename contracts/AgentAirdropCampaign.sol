// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IAgentAirdropTypes.sol";
import "./interfaces/IAgentAirdropCampaign.sol";

/// @title AgentAirdropCampaign
/// @notice Manages a single AgentToken airdrop campaign
/// @dev Uses Merkle Tree to verify user eligibility and manages token funds for a single airdrop campaign
contract AgentAirdropCampaign is Initializable, OwnableUpgradeable, IAgentAirdropCampaign, IAgentAirdropTypes {
    using SafeERC20 for IERC20;

    /// @notice Airdrop campaign information
    Campaign private _campaign;

    /// @notice User claim record mapping account => claimed
    mapping(address => bool) private _claimed;

    /// @notice Router contract address
    address private _router;

    /// @notice Modifier for router contract only
    modifier onlyRouter() {
        if (msg.sender != _router) revert NotAuthorized();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentAirdropCampaign
    function initialize(
        address router,
        bytes32 merkleRoot,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    ) external initializer {
        __Ownable_init();
        _transferOwnership(router);

        // Validate parameters
        if (router == address(0)) revert InvalidRouterAddress();
        if (merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (token == address(0)) revert InvalidTokenAddress();
        if (startTime >= endTime) revert InvalidTimeSettings();
        if (endTime < block.timestamp) revert InvalidTimeSettings();
        if (totalAmount == 0) revert InvalidAmount();

        _router = router;

        // Initialize airdrop campaign
        _campaign = Campaign({
            merkleRoot: merkleRoot,
            token: token,
            startTime: startTime,
            endTime: endTime,
            active: false,
            totalAmount: totalAmount,
            claimedAmount: 0
        });

        emit CampaignInitialized(
            merkleRoot,
            token,
            startTime,
            endTime,
            totalAmount
        );
    }

    /// @inheritdoc IAgentAirdropCampaign
    function setTimeSettings(
        uint256 startTime,
        uint256 endTime
    ) external onlyRouter {
        // Validate time settings
        if (startTime >= endTime) revert InvalidTimeSettings();
        if (endTime < block.timestamp) revert InvalidTimeSettings();
        
        // Update time settings
        _campaign.startTime = startTime;
        _campaign.endTime = endTime;
        
        emit TimeSettingsUpdated(
            startTime,
            endTime
        );
    }

    /// @inheritdoc IAgentAirdropCampaign
    function setActive(bool active) external onlyRouter {
        // Update activation status
        _campaign.active = active;
        
        emit ActiveStatusUpdated(active);
    }

    /// @inheritdoc IAgentAirdropCampaign
    function getStatus() external view returns (CampaignStatus) {
        if (!_campaign.active) {
            return CampaignStatus.Inactive;
        }
        
        uint256 currentTime = block.timestamp;
        
        if (currentTime < _campaign.startTime) {
            return CampaignStatus.Pending;
        } else if (currentTime <= _campaign.endTime) {
            return CampaignStatus.Ongoing;
        } else {
            return CampaignStatus.Ended;
        }
    }

    /// @inheritdoc IAgentAirdropCampaign
    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external onlyRouter {
        // Get current status
        CampaignStatus status = this.getStatus();
        
        // Validate campaign status
        if (status != CampaignStatus.Ongoing) revert CampaignNotOngoing();
        
        // Validate if already claimed
        if (_claimed[account]) revert AlreadyClaimed();
        
        // Validate Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        if (!MerkleProof.verify(merkleProof, _campaign.merkleRoot, leaf)) revert InvalidMerkleProof();
        
        // Mark as claimed
        _claimed[account] = true;
        
        // Update total claimed amount
        _campaign.claimedAmount += amount;
        
        // Transfer tokens
        IERC20(_campaign.token).safeTransfer(account, amount);
        
        emit Claimed(account, amount);
    }

    /// @inheritdoc IAgentAirdropCampaign
    function checkClaimableAmount(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        // Get current status
        CampaignStatus status = this.getStatus();
        
        // Validate campaign status
        if (status != CampaignStatus.Ongoing) return false;
        
        // Validate if already claimed
        if (_claimed[account]) return false;
        
        // Validate Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        return MerkleProof.verify(merkleProof, _campaign.merkleRoot, leaf);
    }

    /// @inheritdoc IAgentAirdropCampaign
    function hasClaimed(address account) external view returns (bool) {
        return _claimed[account];
    }

    /// @inheritdoc IAgentAirdropCampaign
    function withdrawReversed(address recipient) external onlyRouter {
        if (recipient == address(0)) revert InvalidRecipientAddress();
        
        // Get current status
        CampaignStatus status = this.getStatus();
        
        // Validate campaign has ended
        if (status != CampaignStatus.Ended) 
            revert CampaignNotEnded();
        
        // Calculate unclaimed amount
        uint256 unclaimedAmount = _campaign.totalAmount - _campaign.claimedAmount;
        if (unclaimedAmount == 0) revert InvalidAmount();
        
        // Transfer unclaimed tokens
        IERC20(_campaign.token).safeTransfer(recipient, unclaimedAmount);
        
        emit WithdrawnReversed(
            _campaign.token,
            unclaimedAmount,
            recipient
        );
    }

    /// @inheritdoc IAgentAirdropCampaign
    function addTokens(uint256 additionalAmount) external onlyRouter {
        if (additionalAmount == 0) revert InvalidAmount();
        
        // Get current status
        CampaignStatus status = this.getStatus();
        
        // Validate campaign status
        if (status == CampaignStatus.Ended) revert CampaignEnded();
        
        // Update total amount
        _campaign.totalAmount += additionalAmount;
        
        // Emit event
        emit TokensAdded(
            _campaign.token,
            additionalAmount,
            _campaign.totalAmount
        );
    }

    /// @inheritdoc IAgentAirdropCampaign
    function getCampaign() external view returns (Campaign memory) {
        return _campaign;
    }

    /// @inheritdoc IAgentAirdropCampaign
    function getRemainingAmount() external view returns (uint256) {
        return _campaign.totalAmount - _campaign.claimedAmount;
    }

    /// @dev OpenZeppelin storage gap for future upgrades
    uint256[50] private __gap;
} 