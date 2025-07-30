// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAgentConfig.sol";
import "./interfaces/IAgentTypes.sol";
/// @title AgentConfig
/// @notice Agent configuration contract
/// @dev Manages Agent system configuration parameters
contract AgentConfig is Initializable, OwnableUpgradeable, IAgentConfig, IAgentTypes {
    /// @notice Agent token base unit, 1e18
    uint256 private constant AGENT_TOKEN = 1e18;

    /// @notice Stake amount
    uint256 private _stakeAmount;

    /// @notice Agent token total supply
    uint256 private _agentTokenTotalSupply;
    /// @notice Investment unit amount
    uint256 private _investmentUnit;

    /// @notice Linear unlock period
    uint256 private _linearUnlockPeriod;
    /// @notice Seed stage unlock period count
    uint256 private _seedingUnlockPeriodCount;
    /// @notice Acceleration stage unlock period count
    uint256 private _accelerationUnlockPeriodCount;

    /// @notice Genesis succeeded stage duration
    uint256 private _stageDurationGenesisSucceeded;
    /// @notice Seed stage duration
    uint256 private _stageDurationSeeding;
    /// @notice Seed stage succeeded stage duration
    uint256 private _stageDurationSeedingSucceeded;
    /// @notice Acceleration stage duration
    uint256 private _stageDurationAcceleration;

    /// @notice Seed stage target raise amount
    uint256 private _seedingGoal;
    /// @notice Seed stage minimum number of investors
    uint256 private _seedingMinInvestors;
    /// @notice Seed stage maximum individual investment amount
    uint256 private _seedingMaxIndividualInvest;
    /// @notice Seed stage allocation percentage (parts per million)
    uint256 private _seedingAllocationPercentage;

    /// @notice Acceleration stage target raise amount
    uint256 private _accelerationGoal;
    /// @notice Acceleration stage minimum number of investors
    uint256 private _accelerationMinInvestors;
    /// @notice Acceleration stage maximum individual investment amount
    uint256 private _accelerationMaxIndividualInvest;
    /// @notice Acceleration stage allocation percentage (parts per million)
    uint256 private _accelerationAllocationPercentage;
    /// @notice Acceleration stage virtual ETH amount
    uint256 private _accelerationVirtualETH;
    /// @notice Acceleration stage virtual Agent token amount
    uint256 private _accelerationVirtualAgentToken;

    /// @notice Aerodrome router address
    address private _aerodromeRouter;
    /// @notice Aerodrome pool ETH amount
    uint256 private _aerodromePoolETHAmount;
    /// @notice Aerodrome pool Agent token amount
    uint256 private _aerodromePoolAgentTokenAmount;

    /// @notice Seed stage refund fee rate (parts per million)
    uint256 private _refundSeedingFeeRate;
    /// @notice Acceleration stage refund fee rate (parts per million)
    uint256 private _refundAccelerationFeeRate;

    /// @notice Service fee period
    uint256 private _serviceFeePeriod;
    /// @notice Service fee rate (parts per million)
    uint256 private _serviceFeeRate;

    /// @notice Fee recipient address
    address private _feeReceipient;

    /// @notice Factory contract address
    address private _agentFactory;

    /// @notice Agent router address
    address private _agentRouter;

    /// @notice Agent signer address
    address private _agentSigner;

    /// @notice Agent oracle address
    address private _agentOracle;

    /// @notice Default unlock strategy
    UnlockStrategyType private _defaultUnlockStrategy;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentConfig
    function initialize(address _owner, InitializeParams calldata _params) external initializer override {
        __Ownable_init();
        _transferOwnership(_owner);

        // Initialize parameters
        _stakeAmount = _params.stakeAmount;

        _linearUnlockPeriod = _params.linearUnlockPeriod;
        _seedingUnlockPeriodCount = _params.seedingUnlockPeriodCount;
        _accelerationUnlockPeriodCount = _params.accelerationUnlockPeriodCount;

        _agentTokenTotalSupply = _params.agentTokenTotalSupply;
        _investmentUnit = _params.investmentUnit;

        _stageDurationGenesisSucceeded = _params.stageDurationGenesisSucceeded;
        _stageDurationSeeding = _params.stageDurationSeeding;
        _stageDurationSeedingSucceeded = _params.stageDurationSeedingSucceeded;
        _stageDurationAcceleration = _params.stageDurationAcceleration;

        _seedingGoal = _params.seedingGoal;
        _seedingMinInvestors = _params.seedingMinInvestors;
        _seedingMaxIndividualInvest = _seedingGoal / _seedingMinInvestors;
        _seedingAllocationPercentage = _params.seedingAllocationPercentage;

        _accelerationGoal = _params.accelerationGoal;
        _accelerationMinInvestors = _params.accelerationMinInvestors;
        _accelerationMaxIndividualInvest = _accelerationGoal / _accelerationMinInvestors;
        _accelerationAllocationPercentage = _params.accelerationAllocationPercentage;
        _accelerationVirtualETH = _params.accelerationVirtualETH;
        _accelerationVirtualAgentToken = _params.accelerationVirtualAgentToken;

        _aerodromeRouter = _params.aerodromeRouter;
        _aerodromePoolETHAmount = _params.aerodromePoolETHAmount;
        _aerodromePoolAgentTokenAmount = _params.aerodromePoolAgentTokenAmount;

        _feeReceipient = _params.feeReceipient == address(0) ? owner() : _params.feeReceipient;
        _refundSeedingFeeRate = _params.refundSeedingFeeRate;
        _refundAccelerationFeeRate = _params.refundAccelerationFeeRate;

        _serviceFeePeriod = _params.serviceFeePeriod;
        _serviceFeeRate = _params.serviceFeeRate;

        _agentSigner = _params.agentSigner;
        _agentOracle = _params.agentOracle;
        
        _defaultUnlockStrategy = _params.defaultUnlockStrategy;
    }

    function _requireConfig(bool condition, string memory description) internal pure {
        if (!condition) revert InvalidConfig(description);
    }

    function checkConfigValidation() internal view {
        _requireConfig(_stakeAmount % _investmentUnit == 0, "Stake amount must be a multiple of investment unit");
        _requireConfig(_seedingGoal % _investmentUnit == 0, "Seeding goal must be a multiple of investment unit");
        _requireConfig(_accelerationGoal % _investmentUnit == 0, "Acceleration goal must be a multiple of investment unit");
        _requireConfig(_seedingAllocationPercentage + _accelerationAllocationPercentage <= 1_000_000, "Allocation percentage must be less than or equal to 100%");
    }

    /// @notice Validate config
    /// @dev Validate config after any operation
    modifier validateConfig() {
        _;
        checkConfigValidation();
    }

    /// @inheritdoc IAgentConfig
    function getStakeAmount() external view override returns (uint256) {
        return _stakeAmount;
    }

    /// @inheritdoc IAgentConfig
    function setStakeAmount(uint256 amount) external override onlyOwner validateConfig {
        uint256 oldValue = _stakeAmount;
        _stakeAmount = amount;
        emit ConfigUpdated("stakeAmount", oldValue, amount);
    }

    /// @inheritdoc IAgentConfig
    function getAgentTokenTotalSupply() external view override returns (uint256) {
        return _agentTokenTotalSupply;
    }

    /// @inheritdoc IAgentConfig
    function getInvestmentUnit() external view override returns (uint256) {
        return _investmentUnit;
    }

    /// @inheritdoc IAgentConfig
    function setAgentTokenTotalSupply(uint256 totalSupply) external override onlyOwner {
        uint256 oldValue = _agentTokenTotalSupply;
        _agentTokenTotalSupply = totalSupply;
        emit ConfigUpdated("agentTokenTotalSupply", oldValue, totalSupply);
    }

    /// @inheritdoc IAgentConfig
    function setInvestmentUnit(uint256 unit) external override onlyOwner validateConfig {
        uint256 oldValue = _investmentUnit;
        _investmentUnit = unit;
        emit ConfigUpdated("investmentUnit", oldValue, unit);
    }

    /// @inheritdoc IAgentConfig
    function getLinearUnlockPeriod() external view override returns (uint256) {
        return _linearUnlockPeriod;
    }

    /// @inheritdoc IAgentConfig
    function getSeedingUnlockPeriodCount() external view override returns (uint256) {
        return _seedingUnlockPeriodCount;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationUnlockPeriodCount() external view override returns (uint256) {
        return _accelerationUnlockPeriodCount;
    }

    /// @inheritdoc IAgentConfig
    function setLinearUnlockPeriod(uint256 period) external override onlyOwner {
        uint256 oldValue = _linearUnlockPeriod;
        _linearUnlockPeriod = period;
        emit ConfigUpdated("linearUnlockPeriod", oldValue, period);
    }

    /// @inheritdoc IAgentConfig
    function setSeedingUnlockPeriodCount(uint256 count) external override onlyOwner {
        uint256 oldValue = _seedingUnlockPeriodCount;
        _seedingUnlockPeriodCount = count;
        emit ConfigUpdated("seedingUnlockPeriodCount", oldValue, count);
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationUnlockPeriodCount(uint256 count) external override onlyOwner {
        uint256 oldValue = _accelerationUnlockPeriodCount;
        _accelerationUnlockPeriodCount = count;
        emit ConfigUpdated("accelerationUnlockPeriodCount", oldValue, count);
    }

    /// @inheritdoc IAgentConfig
    function getStageDurationGenesisSucceeded() external view override returns (uint256) {
        return _stageDurationGenesisSucceeded;
    }

    /// @inheritdoc IAgentConfig
    function getStageDurationSeeding() external view override returns (uint256) {
        return _stageDurationSeeding;
    }

    /// @inheritdoc IAgentConfig
    function getStageDurationSeedingSucceeded() external view override returns (uint256) {
        return _stageDurationSeedingSucceeded;
    }

    /// @inheritdoc IAgentConfig
    function getStageDurationAcceleration() external view override returns (uint256) {
        return _stageDurationAcceleration;
    }

    /// @inheritdoc IAgentConfig
    function setStageDurationGenesisSucceeded(uint256 duration) external override onlyOwner {
        uint256 oldValue = _stageDurationGenesisSucceeded;
        _stageDurationGenesisSucceeded = duration;
        emit ConfigUpdated("stageDurationGenesisSucceeded", oldValue, duration);
    }

    /// @inheritdoc IAgentConfig
    function setStageDurationSeeding(uint256 duration) external override onlyOwner {
        uint256 oldValue = _stageDurationSeeding;
        _stageDurationSeeding = duration;
        emit ConfigUpdated("stageDurationSeeding", oldValue, duration);
    }

    /// @inheritdoc IAgentConfig
    function setStageDurationSeedingSucceeded(uint256 duration) external override onlyOwner {
        uint256 oldValue = _stageDurationSeedingSucceeded;
        _stageDurationSeedingSucceeded = duration;
        emit ConfigUpdated("stageDurationSeedingSucceeded", oldValue, duration);
    }

    /// @inheritdoc IAgentConfig
    function setStageDurationAcceleration(uint256 duration) external override onlyOwner {
        uint256 oldValue = _stageDurationAcceleration;
        _stageDurationAcceleration = duration;
        emit ConfigUpdated("stageDurationAcceleration", oldValue, duration);
    }

    /// @inheritdoc IAgentConfig
    function getSeedingGoal() external view override returns (uint256) {
        return _seedingGoal;
    }

    /// @inheritdoc IAgentConfig
    function getSeedingMinInvestors() external view override returns (uint256) {
        return _seedingMinInvestors;
    }

    /// @inheritdoc IAgentConfig
    function getSeedingMaxIndividualInvest() external view override returns (uint256) {
        return _seedingMaxIndividualInvest;
    }

    /// @inheritdoc IAgentConfig
    function getSeedingAllocationPercentage() external view override returns (uint256) {
        return _seedingAllocationPercentage;
    }

    /// @inheritdoc IAgentConfig
    function setSeedingGoal(uint256 goal) external override onlyOwner validateConfig {
        uint256 oldValue = _seedingGoal;
        uint256 oldMaxIndividualInvest = _seedingMaxIndividualInvest;
        _seedingGoal = goal;
        _seedingMaxIndividualInvest = _seedingGoal / _seedingMinInvestors;
        emit ConfigUpdated("seedingGoal", oldValue, goal);
        emit ConfigUpdated("seedingMaxIndividualInvest", oldMaxIndividualInvest, _seedingMaxIndividualInvest);
    }

    /// @inheritdoc IAgentConfig
    function setSeedingMinInvestors(uint256 minInvestors) external override onlyOwner {
        uint256 oldValue = _seedingMinInvestors;
        uint256 oldMaxIndividualInvest = _seedingMaxIndividualInvest;
        _seedingMinInvestors = minInvestors;
        _seedingMaxIndividualInvest = _seedingGoal / _seedingMinInvestors;
        emit ConfigUpdated("seedingMinInvestors", oldValue, minInvestors);
        emit ConfigUpdated("seedingMaxIndividualInvest", oldMaxIndividualInvest, _seedingMaxIndividualInvest);
    }

    /// @inheritdoc IAgentConfig
    function setSeedingAllocationPercentage(uint256 percentage) external override onlyOwner validateConfig {
        if (percentage > 1_000_000) revert InvalidPercentage();
        uint256 oldValue = _seedingAllocationPercentage;
        _seedingAllocationPercentage = percentage;
        emit ConfigUpdated("seedingAllocationPercentage", oldValue, percentage);
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationGoal() external view override returns (uint256) {
        return _accelerationGoal;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationMinInvestors() external view override returns (uint256) {
        return _accelerationMinInvestors;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationMaxIndividualInvest() external view override returns (uint256) {
        return _accelerationMaxIndividualInvest;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationAllocationPercentage() external view override returns (uint256) {
        return _accelerationAllocationPercentage;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationVirtualETH() external view override returns (uint256) {
        return _accelerationVirtualETH;
    }

    /// @inheritdoc IAgentConfig
    function getAccelerationVirtualAgentToken() external view override returns (uint256) {
        return _accelerationVirtualAgentToken;
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationGoal(uint256 goal) external override onlyOwner validateConfig {
        uint256 oldValue = _accelerationGoal;
        uint256 oldMaxIndividualInvest = _accelerationMaxIndividualInvest;
        _accelerationGoal = goal;
        _accelerationMaxIndividualInvest = _accelerationGoal / _accelerationMinInvestors;
        emit ConfigUpdated("accelerationGoal", oldValue, goal);
        emit ConfigUpdated("accelerationMaxIndividualInvest", oldMaxIndividualInvest, _accelerationMaxIndividualInvest);
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationMinInvestors(uint256 minInvestors) external override onlyOwner {
        uint256 oldValue = _accelerationMinInvestors;   
        uint256 oldMaxIndividualInvest = _accelerationMaxIndividualInvest;
        _accelerationMinInvestors = minInvestors;
        _accelerationMaxIndividualInvest = _accelerationGoal / _accelerationMinInvestors;
        emit ConfigUpdated("accelerationMinInvestors", oldValue, minInvestors);
        emit ConfigUpdated("accelerationMaxIndividualInvest", oldMaxIndividualInvest, _accelerationMaxIndividualInvest);
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationAllocationPercentage(uint256 percentage) external override onlyOwner validateConfig {
        if (percentage > 1_000_000) revert InvalidPercentage();
        uint256 oldValue = _accelerationAllocationPercentage;
        _accelerationAllocationPercentage = percentage;
        emit ConfigUpdated("accelerationAllocationPercentage", oldValue, percentage);
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationVirtualETH(uint256 virtualETH) external override onlyOwner {
        uint256 oldValue = _accelerationVirtualETH;
        _accelerationVirtualETH = virtualETH;
        emit ConfigUpdated("accelerationVirtualETH", oldValue, virtualETH);
    }

    /// @inheritdoc IAgentConfig
    function setAccelerationVirtualAgentToken(uint256 virtualToken) external override onlyOwner {
        uint256 oldValue = _accelerationVirtualAgentToken;
        _accelerationVirtualAgentToken = virtualToken;
        emit ConfigUpdated("accelerationVirtualAgentToken", oldValue, virtualToken);
    }

    /// @inheritdoc IAgentConfig
    function getAerodromeRouter() external view override returns (address) {
        return _aerodromeRouter;
    }

    /// @inheritdoc IAgentConfig
    function getAerodromePoolETHAmount() external view override returns (uint256) {
        return _aerodromePoolETHAmount;
    }

    /// @inheritdoc IAgentConfig
    function getAerodromePoolAgentTokenAmount() external view override returns (uint256) {
        return _aerodromePoolAgentTokenAmount;
    }

    /// @inheritdoc IAgentConfig
    function setAerodromeRouter(address router) external onlyOwner {
        if (router == address(0)) revert InvalidRouter();

        address oldValue = _aerodromeRouter;
        _aerodromeRouter = router;
        emit ConfigUpdated("aerodromeRouter", uint256(uint160(oldValue)), uint256(uint160(router)));
    }

    /// @inheritdoc IAgentConfig
    function setAerodromePoolETHAmount(uint256 amount) external override onlyOwner {
        uint256 oldValue = _aerodromePoolETHAmount;
        _aerodromePoolETHAmount = amount;
        emit ConfigUpdated("aerodromePoolETHAmount", oldValue, amount);
    }

    /// @inheritdoc IAgentConfig
    function setAerodromePoolAgentTokenAmount(uint256 amount) external override onlyOwner {
        uint256 oldValue = _aerodromePoolAgentTokenAmount;
        _aerodromePoolAgentTokenAmount = amount;
        emit ConfigUpdated("aerodromePoolAgentTokenAmount", oldValue, amount);
    }

    /// @inheritdoc IAgentConfig
    function getRefundSeedingFeeRate() external view override returns (uint256) {
        return _refundSeedingFeeRate;
    }

    /// @inheritdoc IAgentConfig
    function getRefundAccelerationFeeRate() external view override returns (uint256) {
        return _refundAccelerationFeeRate;
    }

    /// @inheritdoc IAgentConfig
    function setRefundSeedingFeeRate(uint256 feeRate) external override onlyOwner {
        if (feeRate > 1_000_000) revert InvalidFeeRate();
        uint256 oldValue = _refundSeedingFeeRate;
        _refundSeedingFeeRate = feeRate;
        emit ConfigUpdated("refundSeedingFeeRate", oldValue, feeRate);
    }

    /// @inheritdoc IAgentConfig
    function setRefundAccelerationFeeRate(uint256 feeRate) external override onlyOwner {
        if (feeRate > 1_000_000) revert InvalidFeeRate();
        uint256 oldValue = _refundAccelerationFeeRate;
        _refundAccelerationFeeRate = feeRate;
        emit ConfigUpdated("refundAccelerationFeeRate", oldValue, feeRate);
    }

    /// @inheritdoc IAgentConfig
    function getServiceFeePeriod() external view override returns (uint256) {
        return _serviceFeePeriod;
    }

    /// @inheritdoc IAgentConfig
    function getServiceFeeRate() external view override returns (uint256) {
        return _serviceFeeRate;
    }

    /// @inheritdoc IAgentConfig
    function setServiceFeePeriod(uint256 period) external override onlyOwner {
        uint256 oldValue = _serviceFeePeriod;
        _serviceFeePeriod = period;
        emit ConfigUpdated("serviceFeePeriod", oldValue, period);
    }

    /// @inheritdoc IAgentConfig
    function setServiceFeeRate(uint256 feeRate) external override onlyOwner {
        if (feeRate > 1_000_000) revert InvalidFeeRate();
        uint256 oldValue = _serviceFeeRate;
        _serviceFeeRate = feeRate;
        emit ConfigUpdated("serviceFeeRate", oldValue, feeRate);
    }

    /// @inheritdoc IAgentConfig
    function getFeeReceipient() external view override returns (address) {
        return _feeReceipient;
    }

    /// @inheritdoc IAgentConfig
    function setFeeReceipient(address feeReceipient) external onlyOwner {
        address oldValue = _feeReceipient;
        _feeReceipient = feeReceipient;
        emit ConfigUpdated("feeReceipient", uint256(uint160(oldValue)), uint256(uint160(feeReceipient)));
    }

    /// @inheritdoc IAgentConfig
    function getAgentFactory() external view override returns (address) {
        return _agentFactory;
    }

    /// @inheritdoc IAgentConfig
    function setAgentFactory(address agentFactory) external onlyOwner {
        address oldValue = _agentFactory;
        _agentFactory = agentFactory;
        emit ConfigUpdated("agentFactory", uint256(uint160(oldValue)), uint256(uint160(agentFactory)));
    }

    /// @inheritdoc IAgentConfig
    function getAgentRouter() external view override returns (address) {
        return _agentRouter;
    }

    /// @inheritdoc IAgentConfig
    function setAgentRouter(address agentRouter) external onlyOwner {
        address oldValue = _agentRouter;
        _agentRouter = agentRouter;
        emit ConfigUpdated("agentRouter", uint256(uint160(oldValue)), uint256(uint160(agentRouter)));
    }

    /// @inheritdoc IAgentConfig
    function getAgentSigner() external view override returns (address) {
        return _agentSigner;
    }

    /// @inheritdoc IAgentConfig
    function setAgentSigner(address agentSigner) external onlyOwner {
        address oldValue = _agentSigner;
        _agentSigner = agentSigner;
        emit ConfigUpdated("agentSigner", uint256(uint160(oldValue)), uint256(uint160(agentSigner)));
    }

    /// @inheritdoc IAgentConfig
    function getAgentOracle() external view override returns (address) {
        return _agentOracle;
    }

    /// @inheritdoc IAgentConfig
    function setAgentOracle(address agentOracle) external onlyOwner {
        address oldValue = _agentOracle;
        _agentOracle = agentOracle;
        emit ConfigUpdated("agentOracle", uint256(uint160(oldValue)), uint256(uint160(agentOracle)));
    }

    /// @inheritdoc IAgentConfig
    function getDefaultUnlockStrategy() external view override returns (UnlockStrategyType) {
        return _defaultUnlockStrategy;
    }

    /// @inheritdoc IAgentConfig
    function setDefaultUnlockStrategy(UnlockStrategyType defaultUnlockStrategy) external onlyOwner {
        UnlockStrategyType oldValue = _defaultUnlockStrategy;
        _defaultUnlockStrategy = defaultUnlockStrategy;
        emit ConfigUpdated("defaultUnlockStrategy", uint256(oldValue), uint256(defaultUnlockStrategy));
    }

    /// @dev OpenZeppelin storage space reserved for adding new storage variables in future upgrades
    uint256[50] private __gap;
} 