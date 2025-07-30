// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAgentTypes.sol";

/// @title IAgentConfig
/// @notice Define the interface for Agent configuration contract, responsible for managing system parameters
/// @dev Implements parameter configuration reading and updating functionality
interface IAgentConfig {
    error InvalidPercentage();
    error InvalidRouter();
    error InvalidFeeRate();
    error InvalidConfig(string conditionDescription);

    struct InitializeParams {
        uint256 stakeAmount;
        uint256 linearUnlockPeriod;
        uint256 seedingUnlockPeriodCount;
        uint256 accelerationUnlockPeriodCount;
        uint256 agentTokenTotalSupply;
        uint256 investmentUnit;
        uint256 stageDurationGenesisSucceeded;
        uint256 stageDurationSeeding;
        uint256 stageDurationSeedingSucceeded;
        uint256 stageDurationAcceleration;
        uint256 seedingGoal;
        uint256 seedingMinInvestors;
        uint256 seedingAllocationPercentage;
        uint256 accelerationGoal;
        uint256 accelerationMinInvestors;
        uint256 accelerationAllocationPercentage;
        uint256 accelerationVirtualETH;
        uint256 accelerationVirtualAgentToken;
        address aerodromeRouter;
        uint256 aerodromePoolETHAmount;
        uint256 aerodromePoolAgentTokenAmount;
        address feeReceipient;
        uint256 refundSeedingFeeRate;
        uint256 refundAccelerationFeeRate;
        uint256 serviceFeePeriod;
        uint256 serviceFeeRate;
        address agentSigner;
        address agentOracle;
        IAgentTypes.UnlockStrategyType defaultUnlockStrategy;
    }

    /// @notice Emitted when configuration parameters are updated
    /// @param paramName Parameter name
    /// @param oldValue Old parameter value
    /// @param newValue New parameter value
    event ConfigUpdated(string paramName, uint256 oldValue, uint256 newValue);

    /// @notice Get the required ETH amount for staking
    /// @return Staking amount
    function getStakeAmount() external view returns (uint256);

    /// @notice Set the required ETH amount for staking
    /// @param amount New staking amount
    function setStakeAmount(uint256 amount) external;

    /// @notice Get the linear unlock period
    /// @return Unlock period (seconds)
    function getLinearUnlockPeriod() external view returns (uint256);

    /// @notice Get the number of seeding round unlock periods
    /// @return Number of unlock periods
    function getSeedingUnlockPeriodCount() external view returns (uint256);

    /// @notice Get the number of acceleration round unlock periods
    /// @return Number of unlock periods
    function getAccelerationUnlockPeriodCount() external view returns (uint256);

    /// @notice Set the linear unlock period
    /// @param period New unlock period (seconds)
    function setLinearUnlockPeriod(uint256 period) external;

    /// @notice Set the number of seeding round token unlock periods
    /// @param count New number of unlock periods
    function setSeedingUnlockPeriodCount(uint256 count) external;

    /// @notice Set the number of acceleration round token unlock periods
    /// @param count New number of unlock periods
    function setAccelerationUnlockPeriodCount(uint256 count) external;

    /// @notice Get the total supply of Agent tokens
    /// @return Total token supply
    function getAgentTokenTotalSupply() external view returns (uint256);

    /// @notice Get the minimum investment unit
    /// @return Minimum investment unit (ETH)
    function getInvestmentUnit() external view returns (uint256);

    /// @notice Set the total supply of Agent tokens
    /// @param totalSupply New total supply
    function setAgentTokenTotalSupply(uint256 totalSupply) external;

    /// @notice Set the minimum investment unit
    /// @param unit New minimum investment unit (ETH)
    function setInvestmentUnit(uint256 unit) external;

    /// @notice Get the genesis succeeded stage duration
    /// @return Duration (seconds)
    function getStageDurationGenesisSucceeded() external view returns (uint256);

    /// @notice Get the seeding round stage duration
    /// @return Duration (seconds)
    function getStageDurationSeeding() external view returns (uint256);

    /// @notice Get the seeding round succeeded stage duration
    /// @return Duration (seconds)
    function getStageDurationSeedingSucceeded() external view returns (uint256);

    /// @notice Get the acceleration round stage duration
    /// @return Duration (seconds)
    function getStageDurationAcceleration() external view returns (uint256);

    /// @notice Set the genesis succeeded stage duration
    /// @param duration New duration (seconds)
    function setStageDurationGenesisSucceeded(uint256 duration) external;

    /// @notice Set the seeding round stage duration
    /// @param duration New duration (seconds)
    function setStageDurationSeeding(uint256 duration) external;

    /// @notice Set the seeding round succeeded stage duration
    /// @param duration New duration (seconds)
    function setStageDurationSeedingSucceeded(uint256 duration) external;

    /// @notice Set the acceleration round stage duration
    /// @param duration New duration (seconds)
    function setStageDurationAcceleration(uint256 duration) external;

    /// @notice Get the seeding round target amount
    /// @return Target amount (ETH)
    function getSeedingGoal() external view returns (uint256);

    /// @notice Get the minimum number of investors for seeding round
    /// @return Minimum number of investors
    function getSeedingMinInvestors() external view returns (uint256);

    /// @notice Get the maximum individual investment amount for seeding round
    /// @return Maximum investment amount (ETH)
    function getSeedingMaxIndividualInvest() external view returns (uint256);

    /// @notice Get the seeding round allocation percentage
    /// @return Allocation percentage (parts per million)
    function getSeedingAllocationPercentage() external view returns (uint256);

    /// @notice Set the seeding round target amount
    /// @param goal New target amount (ETH)
    function setSeedingGoal(uint256 goal) external;

    /// @notice Set the minimum number of investors for seeding round
    /// @param minInvestors New minimum number of investors
    function setSeedingMinInvestors(uint256 minInvestors) external;

    /// @notice Set the seeding round allocation percentage
    /// @param percentage New allocation percentage (parts per million)
    function setSeedingAllocationPercentage(uint256 percentage) external;

    /// @notice Get the acceleration round target amount
    /// @return Target amount (ETH)
    function getAccelerationGoal() external view returns (uint256);

    /// @notice Get the minimum number of investors for acceleration round
    /// @return Minimum number of investors
    function getAccelerationMinInvestors() external view returns (uint256);

    /// @notice Get the maximum individual investment amount for acceleration round
    /// @return Maximum investment amount (ETH)
    function getAccelerationMaxIndividualInvest() external view returns (uint256);

    /// @notice Get the acceleration round allocation percentage
    /// @return Allocation percentage (parts per million)
    function getAccelerationAllocationPercentage() external view returns (uint256);

    /// @notice Get the virtual ETH amount for acceleration round
    /// @return Virtual ETH amount
    function getAccelerationVirtualETH() external view returns (uint256);

    /// @notice Get the virtual Agent token amount for acceleration round
    /// @return Virtual token amount
    function getAccelerationVirtualAgentToken() external view returns (uint256);

    /// @notice Set the acceleration round target amount
    /// @param goal New target amount (ETH)
    function setAccelerationGoal(uint256 goal) external;

    /// @notice Set the minimum number of investors for acceleration round
    /// @param minInvestors New minimum number of investors
    function setAccelerationMinInvestors(uint256 minInvestors) external;

    /// @notice Set the acceleration round allocation percentage
    /// @param percentage New allocation percentage (parts per million)
    function setAccelerationAllocationPercentage(uint256 percentage) external;

    /// @notice Set the virtual ETH amount for acceleration round
    /// @param virtualETH New virtual ETH amount
    function setAccelerationVirtualETH(uint256 virtualETH) external;

    /// @notice Set the virtual Agent token amount for acceleration round
    /// @param virtualToken New virtual token amount
    function setAccelerationVirtualAgentToken(uint256 virtualToken) external;

    /// @notice Get the Aerodrome router contract address
    /// @return Router contract address
    function getAerodromeRouter() external view returns (address);

    /// @notice Get the initial ETH amount for Aerodrome pool
    /// @return ETH amount
    function getAerodromePoolETHAmount() external view returns (uint256);

    /// @notice Get the initial Agent token amount for Aerodrome pool
    /// @return Token amount
    function getAerodromePoolAgentTokenAmount() external view returns (uint256);

    /// @notice Set the Aerodrome router contract address
    /// @param router New router contract address
    function setAerodromeRouter(address router) external;

    /// @notice Set the initial ETH amount for Aerodrome pool
    /// @param amount New ETH amount
    function setAerodromePoolETHAmount(uint256 amount) external;

    /// @notice Set the initial Agent token amount for Aerodrome pool
    /// @param amount New token amount
    function setAerodromePoolAgentTokenAmount(uint256 amount) external;

    /// @notice Get the seeding round refund fee rate
    /// @return Fee rate (parts per million)
    function getRefundSeedingFeeRate() external view returns (uint256);

    /// @notice Get the acceleration round refund fee rate
    /// @return Fee rate (parts per million)
    function getRefundAccelerationFeeRate() external view returns (uint256);

    /// @notice Set the seeding round refund fee rate
    /// @param fee New fee rate (parts per million)
    function setRefundSeedingFeeRate(uint256 fee) external;

    /// @notice Set the acceleration round refund fee rate
    /// @param fee New fee rate (parts per million)
    function setRefundAccelerationFeeRate(uint256 fee) external;

    /// @notice Get the service fee period
    /// @return Service fee period (seconds)
    function getServiceFeePeriod() external view returns (uint256);

    /// @notice Get the service fee rate
    /// @return Service fee rate (parts per million)
    function getServiceFeeRate() external view returns (uint256);

    /// @notice Set the service fee period
    /// @param period New service fee period (seconds)
    function setServiceFeePeriod(uint256 period) external;

    /// @notice Set the service fee rate
    /// @param rate New service fee rate (parts per million)
    function setServiceFeeRate(uint256 rate) external;

    /// @notice Get the fee receipient address
    /// @return Receipient address
    function getFeeReceipient() external view returns (address);

    /// @notice Set the fee receipient address
    /// @param receipient New receipient address
    function setFeeReceipient(address receipient) external;

    /// @notice Initialize the contract
    /// @param _owner Contract owner address
    /// @param _params Initialization parameters
    function initialize(address _owner, InitializeParams calldata _params) external;

    /// @notice Get the Agent factory address
    /// @return Factory address
    function getAgentFactory() external view returns (address);

    /// @notice Set the Agent factory address
    /// @param agentFactory New factory address
    function setAgentFactory(address agentFactory) external;

    /// @notice Get the Agent Router address
    /// @return Router address
    function getAgentRouter() external view returns (address);

    /// @notice Set the Agent Router address
    /// @param agentRouter New router address
    function setAgentRouter(address agentRouter) external;

    /// @notice Get the Agent Signer address
    /// @return Address
    function getAgentSigner() external view returns (address);

    /// @notice Set the Agent Signer address
    /// @dev Set to 0 address to disable signature verification
    /// @param agentSigner New address
    function setAgentSigner(address agentSigner) external;

    /// @notice Get the Agent Oracle address
    /// @return Address
    function getAgentOracle() external view returns (address);

    /// @notice Set the Agent Oracle address
    /// @param agentOracle New address
    function setAgentOracle(address agentOracle) external;

    /// @notice Get the default unlock strategy
    /// @return Unlock strategy
    function getDefaultUnlockStrategy() external view returns (IAgentTypes.UnlockStrategyType);

    /// @notice Set the default unlock strategy
    /// @param defaultUnlockStrategy New default unlock strategy
    function setDefaultUnlockStrategy(IAgentTypes.UnlockStrategyType defaultUnlockStrategy) external;
}
