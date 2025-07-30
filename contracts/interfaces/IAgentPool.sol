// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAgentPool
/// @notice Agent investment pool interface, defines core functionality of the investment pool
/// @dev Implements investment, refund and service fee management functions
interface IAgentPool {
    error InvalidOwner();
    error InvalidInvestmentUnit();
    error InvestRefused();
    error InvalidAgentTokenOut();
    error ExceedsMaximumIndividualSeedingAmount();
    error ExceedsMaximumIndividualAccelerationAmount();
    error InvalidStage();
    error InvalidInvestAmount();
    error NoRefundAvailable();
    error NoServiceFeeAvailable();
    error InvalidRecipient();
    error InsufficientOutputAmount();
    error InsufficientBalance();
    error NotAuthorized();
    error InvalidCustodian();
    error CustodianAlreadySet();
    error NotCustodian();
    error NotInThrivingStage();
    error NotAgentRouter();
    error EthTransferFailed();
    error InvalidAerodromePool();

    /// @notice Investment pool stage enum
    /// @dev Defines seven stages of the investment pool, from genesis to failure
    enum Stage {
        Genesis,          // 0 - Initial stage, just created
        GenesisSucceeded, // 1 - Announcement period (24 hours)
        Seeding,          // 2 - Seed stage
        SeedingSucceeded, // 3 - Seed stage succeeded
        Acceleration,     // 4 - Acceleration stage
        Thriving,         // 5 - Thriving period
        Failed            // 6 - Failure at any stage
    }

    /// @notice Investment record structure
    /// @dev Records user's investment in seed and acceleration stages
    struct Investment {
        uint256 seedingEthIn;           // ETH amount invested in seed stage
        uint256 seedingAgentTokenOut;   // Agent tokens obtained in seed stage
        uint256 accelerationEthIn;      // ETH amount invested in acceleration stage
        uint256 accelerationAgentTokenOut; // Agent tokens obtained in acceleration stage
    }

    /// @notice Investment accepted event
    /// @param agentToken Agent token address
    /// @param investor Investor address
    /// @param ethIn Invested ETH amount
    /// @param agentTokenOut Obtained Agent token amount
    /// @param currentStage Current stage
    event InvestmentAccepted(
        address indexed agentToken,
        address indexed investor,
        uint256 ethIn,
        uint256 agentTokenOut,
        Stage currentStage
    );

    /// @notice Stage change event
    /// @param stage New stage
    /// @param startTime Start time
    /// @param endTime End time
    event StageChanged(
        Stage stage,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Refund claimed event
    /// @param agentToken Agent token address
    /// @param investor Investor address
    /// @param seedingETH Seed stage refund amount
    /// @param accelerationETH Acceleration stage refund amount
    /// @param seedingAgentToken Seed stage returned token amount
    /// @param accelerationAgentToken Acceleration stage returned token amount
    /// @param seedingRefundFee Seed stage refund fee
    /// @param accelerationRefundFee Acceleration stage refund fee
    event RefundClaimed(
        address indexed agentToken,
        address indexed investor,
        uint256 seedingETH,
        uint256 accelerationETH,
        uint256 seedingAgentToken,
        uint256 accelerationAgentToken,
        uint256 seedingRefundFee,
        uint256 accelerationRefundFee
    );

    /// @notice Service fee claimed event
    /// @param agentToken Agent token address
    /// @param recipient Recipient address
    /// @param serviceFee Service fee amount
    /// @param servicePeriodStart Service fee period start time
    /// @param servicePeriodEnd Service fee period end time
    event ServiceFeeClaimed(
        address indexed agentToken,
        address indexed recipient,
        uint256 serviceFee,
        uint256 servicePeriodStart,
        uint256 servicePeriodEnd
    );

    /// @notice Custodian set event
    /// @param agentToken Agent token address
    /// @param custodian Custodian address
    event CustodianSet(
        address indexed agentToken,
        address indexed custodian
    );

    /// @notice Funds withdrawn event
    /// @param agentToken Agent token address
    /// @param custodian Custodian address
    /// @param recipient Recipient address
    /// @param tokenAddress Withdrawn token address
    /// @param tokenAmount Withdrawn token amount
    event FundsWithdrawn(
        address indexed agentToken,
        address indexed custodian,
        address recipient,
        address tokenAddress,
        uint256 tokenAmount
    );

    /// @notice Initialize investment pool
    /// @param _agentToken Agent token address
    /// @param _agentConfig Configuration contract address
    /// @param _initialInvestor Initial investor address
    /// @param _owner Contract owner address
    /// @return ethIn Initial invested ETH amount
    /// @return agentTokenOut Initial obtained Agent token amount
    function initialize(
        address _agentToken,
        address _agentConfig,
        address _initialInvestor,
        address _owner
    ) external payable returns (uint256 ethIn, uint256 agentTokenOut);

    /// @notice Get Agent token address
    /// @return Agent token contract address
    function agentToken() external view returns (address);

    /// @notice Get configuration contract address
    /// @return Configuration contract address
    function agentConfig() external view returns (address);

    /// @notice Get fee recipient address
    /// @return Fee recipient address
    function feeReceipient() external view returns (address);

    /// @notice Get service fee period
    /// @return Service fee period (seconds)
    function serviceFeePeriod() external view returns (uint256);

    /// @notice Get service fee rate
    /// @return Service fee rate (parts per million)
    function serviceFeeRate() external view returns (uint256);

    /// @notice Get current stage information
    /// @return stage Current stage
    /// @return startTime Current stage start time
    /// @return endTime Current stage end time
    function getCurrentStage() external view returns (Stage stage, uint256 startTime, uint256 endTime);

    /// @notice Get investment record for specified address
    /// @param investor Investor address
    /// @return Investment record
    function investmentFor(address investor) external view returns (Investment memory);

    /// @notice Calculate Agent token amount obtainable from investment
    /// @param ethIn Invested ETH amount
    /// @return acceptedEthIn Accepted ETH amount
    /// @return agentTokenOut Obtainable Agent token amount
    function getAgentTokenOut(uint256 ethIn) external view returns (uint256 acceptedEthIn, uint256 agentTokenOut);

    /// @notice Invest ETH to get Agent tokens
    /// @param minAgentTokenOut Minimum acceptable Agent token amount
    /// @param recipient Recipient address
    /// @return acceptedEthIn Accepted ETH amount
    /// @return agentTokenOut Obtained Agent token amount
    function invest(
        uint256 minAgentTokenOut,
        address recipient
    ) external payable returns (uint256 acceptedEthIn, uint256 agentTokenOut);

    /// @notice Claim fees from Aerodrome pool
    /// @return amountToken Received token amount
    /// @return amountETH Received ETH amount
    function claimFeesFromAerodromePool() external returns (
        uint256 amountToken,
        uint256 amountETH
    );

    /// @notice Query refundable amount
    /// @param recipient Recipient address
    /// @return Refundable ETH amount
    function refundFor(address recipient) external view returns (uint256);

    /// @notice Claim refund
    /// @param recipient Recipient address
    function claimRefund(address recipient) external;

    /// @notice Query pending service fee
    /// @return Pending service fee amount
    function pendingServiceFee() external view returns (uint256);

    /// @notice Claim service fee
    function claimServiceFee() external;

    /// @notice Get seed stage investor list
    /// @param start Start index
    /// @param end End index
    /// @return Investor address array
    function getSeedingInvestors(uint256 start, uint256 end) external view returns (address[] memory);
    
    /// @notice Get seed stage investor count
    /// @return Investor count
    function getSeedingInvestorsCount() external view returns (uint256);
    
    /// @notice Get acceleration stage investor list
    /// @param start Start index
    /// @param end End index
    /// @return Investor address array
    function getAccelerationInvestors(uint256 start, uint256 end) external view returns (address[] memory);
    
    /// @notice Get acceleration stage investor count
    /// @return Investor count
    function getAccelerationInvestorsCount() external view returns (uint256);

    /// @notice Set Agent custodian address
    /// @param custodian Custodian address
    function setCustodian(address custodian) external;

    /// @notice Get current custodian address
    /// @return Custodian address
    function custodian() external view returns (address);

    /// @notice Withdraw funds
    /// @param recipient Recipient address
    /// @param tokenAddress Token address to withdraw, 0 for ETH
    /// @param tokenAmount Token amount to withdraw
    function withdrawFunds(
        address recipient,
        address tokenAddress,
        uint256 tokenAmount
    ) external;
}
