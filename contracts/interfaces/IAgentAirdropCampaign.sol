// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentAirdropTypes.sol";

/// @notice Agent airdrop campaign contract interface, responsible for managing a single airdrop campaign
/// @dev Manages token funds and claim logic for a single airdrop campaign
interface IAgentAirdropCampaign {
    /// @notice Event: Initialize airdrop campaign
    /// @param merkleRoot Merkle Tree root hash
    /// @param token Airdrop token address
    /// @param startTime Start time
    /// @param endTime End time
    /// @param totalAmount Total airdrop amount
    event CampaignInitialized(
        bytes32 indexed merkleRoot,
        address indexed token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    );

    /// @notice Event: Update airdrop campaign time settings
    /// @param startTime Start time
    /// @param endTime End time
    event TimeSettingsUpdated(
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Event: Update airdrop campaign activation status
    /// @param active Whether activated
    event ActiveStatusUpdated(
        bool active
    );

    /// @notice Event: Claim airdrop
    /// @param account Claiming account
    /// @param amount Claim amount
    event Claimed(
        address indexed account,
        uint256 amount
    );

    /// @notice Event: Withdraw unclaimed tokens
    /// @param token Token address
    /// @param amount Withdrawal amount
    /// @param recipient Recipient address
    event WithdrawnReversed(
        address indexed token,
        uint256 amount,
        address recipient
    );

    /// @notice Event: Add tokens to airdrop campaign
    /// @param token Token address
    /// @param amount Amount to add
    /// @param newTotalAmount New total amount
    event TokensAdded(
        address indexed token,
        uint256 amount,
        uint256 newTotalAmount
    );

    /// @notice Initialize airdrop campaign contract
    /// @param router Router contract address
    /// @param merkleRoot Merkle Tree root hash
    /// @param token Airdrop token address
    /// @param startTime Start time
    /// @param endTime End time
    /// @param totalAmount Total airdrop amount
    function initialize(
        address router,
        bytes32 merkleRoot,
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    ) external;

    /// @notice Set airdrop campaign time
    /// @param startTime Start time
    /// @param endTime End time
    function setTimeSettings(
        uint256 startTime,
        uint256 endTime
    ) external;

    /// @notice Set airdrop campaign activation status
    /// @param active Whether activated
    function setActive(bool active) external;

    /// @notice Get current airdrop campaign status
    /// @return Airdrop campaign status
    function getStatus() external view returns (IAgentAirdropTypes.CampaignStatus);

    /// @notice Claim airdrop
    /// @param account Claiming account
    /// @param amount Claim amount
    /// @param merkleProof Merkle proof
    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    /// @notice Query user's claimable amount
    /// @param account Query account
    /// @param amount Claim amount
    /// @param merkleProof Merkle proof
    /// @return Whether claimable
    function checkClaimableAmount(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool);

    /// @notice Query if user has claimed
    /// @param account Query account
    /// @return Whether claimed
    function hasClaimed(address account) external view returns (bool);

    /// @notice Withdraw unclaimed tokens (only callable by router contract)
    /// @param recipient Recipient address
    function withdrawReversed(address recipient) external;

    /// @notice Add more tokens to airdrop campaign
    /// @param additionalAmount Additional token amount
    function addTokens(uint256 additionalAmount) external;

    /// @notice Get airdrop campaign information
    /// @return Airdrop campaign information
    function getCampaign() external view returns (IAgentAirdropTypes.Campaign memory);

    /// @notice Get remaining claimable amount of airdrop campaign
    /// @return Remaining claimable amount
    function getRemainingAmount() external view returns (uint256);
} 