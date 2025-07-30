// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentAirdropTypes.sol";

/// @title IAgentAirdropRouter
/// @notice Agent Airdrop Router Contract Interface, responsible for creating and managing airdrop campaigns
/// @dev Manages multiple airdrop campaigns and forwards operations to the corresponding airdrop campaign contracts
interface IAgentAirdropRouter {
    /// @notice Event: Airdrop Campaign Created
    /// @param campaignId Airdrop Campaign ID
    /// @param campaignAddress Airdrop Campaign Contract Address
    /// @param merkleRoot Merkle Tree Root Hash
    /// @param token Airdrop Token Address
    /// @param startTime Start Time
    /// @param endTime End Time
    /// @param totalAmount Total Airdrop Amount
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed campaignAddress,
        bytes32 indexed merkleRoot,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    );

    /// @notice Event: Airdrop Campaign Time Settings Updated
    /// @param campaignId Airdrop Campaign ID
    /// @param startTime Start Time
    /// @param endTime End Time
    event TimeSettingsUpdated(
        uint256 indexed campaignId,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Event: Airdrop Campaign Active Status Updated
    /// @param campaignId Airdrop Campaign ID
    /// @param active Active Status
    event ActiveStatusUpdated(
        uint256 indexed campaignId,
        bool active
    );

    /// @notice Initialize Airdrop Router Contract
    /// @param _owner Contract Owner
    /// @param _implementation Airdrop Campaign Contract Implementation Address
    function initialize(address _owner, address _implementation) external;

    /// @notice Create New Airdrop Campaign
    /// @param merkleRoot Merkle Tree Root Hash
    /// @param token Airdrop Token Address
    /// @param startTime Start Time
    /// @param endTime End Time
    /// @param totalAmount Total Airdrop Amount
    /// @return campaignId Airdrop Campaign ID
    /// @return campaignAddress Airdrop Campaign Contract Address
    /// @dev Caller needs to approve the contract to transfer totalAmount of tokens first
    function createCampaign(
        bytes32 merkleRoot,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    ) external returns (uint256 campaignId, address campaignAddress);

    /// @notice Set Airdrop Campaign Time Settings
    /// @param campaignId Airdrop Campaign ID
    /// @param startTime Start Time
    /// @param endTime End Time
    function setTimeSettings(
        uint256 campaignId,
        uint256 startTime,
        uint256 endTime
    ) external;

    /// @notice Set Airdrop Campaign Active Status
    /// @param campaignId Airdrop Campaign ID
    /// @param active Active Status
    function setActive(uint256 campaignId, bool active) external;

    /// @notice Get Current Status of Airdrop Campaign
    /// @param campaignId Airdrop Campaign ID
    /// @return Airdrop Campaign Status
    function getStatus(uint256 campaignId) external view returns (IAgentAirdropTypes.CampaignStatus);

    /// @notice Claim Airdrop
    /// @param campaignId Airdrop Campaign ID
    /// @param account Claim Account
    /// @param amount Claim Amount
    /// @param merkleProof Merkle Proof
    function claim(
        uint256 campaignId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    /// @notice Batch Claim Airdrop
    /// @param campaignIds Array of Airdrop Campaign IDs
    /// @param account Claim Account
    /// @param amounts Array of Claim Amounts
    /// @param merkleProofs Array of Merkle Proofs
    function batchClaim(
        uint256[] calldata campaignIds,
        address account,
        uint256[] calldata amounts,
        bytes32[][] calldata merkleProofs
    ) external;

    /// @notice Check Claimable Amount for User
    /// @param campaignId Airdrop Campaign ID
    /// @param account Query Account
    /// @param amount Claim Amount
    /// @param merkleProof Merkle Proof
    /// @return Whether Claimable
    function checkClaimableAmount(
        uint256 campaignId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool);

    /// @notice Check if User Has Claimed
    /// @param campaignId Airdrop Campaign ID
    /// @param account Query Account
    /// @return Whether Claimed
    function hasClaimed(uint256 campaignId, address account) external view returns (bool);

    /// @notice Withdraw Unclaimed Tokens (Admin Only, Airdrop Campaign Must Be Ended)
    /// @param campaignId Airdrop Campaign ID
    /// @param recipient Recipient Address
    function withdrawReversed(uint256 campaignId, address recipient) external;

    /// @notice Add More Tokens to Airdrop Campaign
    /// @param campaignId Airdrop Campaign ID
    /// @param additionalAmount Additional Token Amount
    /// @dev Caller needs to approve the contract to transfer additionalAmount of tokens first
    function addTokens(uint256 campaignId, uint256 additionalAmount) external;

    /// @notice Get Airdrop Campaign Contract Address
    /// @param campaignId Airdrop Campaign ID
    /// @return Airdrop Campaign Contract Address
    function getCampaignAddress(uint256 campaignId) external view returns (address);

    /// @notice Get Airdrop Campaign Information
    /// @param campaignId Airdrop Campaign ID
    /// @return Airdrop Campaign Information
    function getCampaign(uint256 campaignId) external view returns (IAgentAirdropTypes.Campaign memory);

    /// @notice Get Number of Airdrop Campaigns
    /// @return Number of Airdrop Campaigns
    function getCampaignCount() external view returns (uint256);

    /// @notice Get Remaining Claimable Amount of Airdrop Campaign
    /// @param campaignId Airdrop Campaign ID
    /// @return Remaining Claimable Amount
    function getRemainingAmount(uint256 campaignId) external view returns (uint256);

    /// @notice Set Airdrop Campaign Contract Implementation Address
    /// @param _implementation New Implementation Address
    function setImplementation(address _implementation) external;
} 