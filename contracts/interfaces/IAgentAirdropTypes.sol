// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAgentAirdropTypes
/// @notice Define shared types, structures and errors for AgentAirdrop system
/// @dev Imported by other interfaces and contracts to ensure type definition consistency
interface IAgentAirdropTypes {
    /// @notice Airdrop campaign status enum
    enum CampaignStatus {
        Inactive,   // Not activated
        Pending,    // Pending start
        Ongoing,    // In progress
        Ended       // Ended
    }

    /// @notice Airdrop campaign structure
    /// @param merkleRoot Merkle Tree root hash
    /// @param token Airdrop token address
    /// @param startTime Start time
    /// @param endTime End time
    /// @param active Whether activated
    /// @param totalAmount Total airdrop amount
    /// @param claimedAmount Total claimed amount
    struct Campaign {
        bytes32 merkleRoot;
        address token;
        uint256 startTime;
        uint256 endTime;
        bool active;
        uint256 totalAmount;
        uint256 claimedAmount;
    }

    /// @notice Error: Unauthorized call
    error NotAuthorized();
    /// @notice Error: Invalid airdrop campaign ID
    error InvalidCampaignId();
    /// @notice Error: Invalid Merkle root
    error InvalidMerkleRoot();
    /// @notice Error: Invalid token address
    error InvalidTokenAddress();
    /// @notice Error: Invalid router address
    error InvalidRouterAddress();
    /// @notice Error: Invalid recipient address
    error InvalidRecipientAddress();
    /// @notice Error: Invalid time settings
    error InvalidTimeSettings();
    /// @notice Error: Invalid amount
    error InvalidAmount();
    /// @notice Error: Airdrop campaign not ongoing
    error CampaignNotOngoing();
    /// @notice Error: Airdrop campaign not ended
    error CampaignNotEnded();
    /// @notice Error: Airdrop campaign already ended
    error CampaignEnded();
    /// @notice Error: Already claimed
    error AlreadyClaimed();
    /// @notice Error: Invalid Merkle proof
    error InvalidMerkleProof();
} 