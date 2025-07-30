// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./external/IAerodromeRouter.sol";
import "./external/IAerodromePoolFactory.sol";
import "./external/IAerodromePool.sol";
import "./external/IWETH.sol";

import "./interfaces/IAgentToken.sol";
import "./interfaces/IAgentPool.sol";
import "./interfaces/IAgentConfig.sol";

/// @title AgentPool
/// @notice Agent investment pool
/// @dev Implements investment, refund and service fee management functions
contract AgentPool is IAgentPool, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;
    using SafeERC20Upgradeable for IAgentToken;

    /// @notice Stage time structure
    /// @dev Records start and end time for each stage
    struct StagePeriod {
        uint256 startTime;    // Stage start time
        uint256 endTime;      // Stage end time
    }

    /// @notice Stage time records
    mapping(Stage => StagePeriod) public stagePeriods;
    /// @notice Last service fee claim time
    uint256 public serviceFeeClaimTime;

    /// @notice Investor investment record mapping
    mapping(address => Investment) internal _investments;
    /// @notice Seed stage investor list
    address[] public seedingInvestors;
    /// @notice Whether is seed stage investor mapping
    mapping(address => bool) internal _isSeedingInvestor;
    /// @notice Acceleration stage investor list
    address[] public accelerationInvestors;
    /// @notice Whether is acceleration stage investor mapping
    mapping(address => bool) internal _isAccelerationInvestor;

    /// @notice Total invested ETH amount
    uint256 public investETHTotal;
    /// @notice Total Agent tokens obtained from investment
    uint256 public investAgentTokenTotal;

    /// @notice Agent token contract
    IAgentToken internal _agentTokenContract;
    /// @notice Agent config contract
    IAgentConfig internal _agentConfigContract;
    /// @notice Aerodrome router contract
    IAerodromeRouter internal _aerodromeRouterContract;

    /// @notice Total supply of Agent tokens
    uint256 public AGENT_TOKEN_TOTAL_SUPPLY;
    /// @notice Investment unit amount
    uint256 public INVESTMENT_UNIT;

    // STAGE DURATION PARAMS
    /// @notice Genesis succeeded stage duration
    uint256 public STAGE_DURATION_GENESIS_SUCCEEDED;
    /// @notice Seed stage duration
    uint256 public STAGE_DURATION_SEEDING;
    /// @notice Seed stage succeeded stage duration
    uint256 public STAGE_DURATION_SEEDING_SUCCEEDED;
    /// @notice Acceleration stage duration
    uint256 public STAGE_DURATION_ACCELERATION;

    // SEEDING PARAMS
    /// @notice Seed stage target raise amount
    uint256 public SEEDING_GOAL;
    /// @notice Seed stage minimum number of investors
    uint256 public SEEDING_MIN_INVESTORS;
    /// @notice Seed stage maximum individual investment amount
    uint256 public SEEDING_MAX_INDIVIDUAL_INVEST;
    /// @notice Seed stage allocation percentage (parts per million)
    uint256 public SEEDING_ALLOCATION_PERCENTAGE;
    /// @notice Seed stage total allocation amount
    uint256 internal SEEDING_ALLOCATION;

    // ACCELERATION PARAMS
    /// @notice Acceleration stage target raise amount
    uint256 public ACCELERATION_GOAL;
    /// @notice Acceleration stage minimum number of investors
    uint256 public ACCELERATION_MIN_INVESTORS;
    /// @notice Acceleration stage maximum individual investment amount
    uint256 public ACCELERATION_MAX_INDIVIDUAL_INVEST;
    /// @notice Acceleration stage allocation percentage (parts per million)
    uint256 public ACCELERATION_ALLOCATION_PPERCENTAGE;
    /// @notice Acceleration stage total allocation amount
    uint256 internal ACCELERATION_ALLOCATION;
    /// @notice Acceleration stage virtual ETH amount
    uint256 internal ACCELERATION_VIRTUAL_ETH;
    /// @notice Acceleration stage virtual Agent token amount
    uint256 internal ACCELERATION_VIRTUAL_AGENT_TOKEN;

    // AERODROME PARAMS
    /// @notice Aerodrome router address
    address public AERODROME_ROUTER;
    /// @notice Aerodrome pool ETH amount
    uint256 public AERODROME_POOL_ETH_AMOUNT;
    /// @notice Aerodrome pool Agent token amount
    uint256 public AERODROME_POOL_AGENT_TOKEN_AMOUNT;

    // REFUND FEE PARAMS
    /// @notice Seed stage refund fee rate (parts per million)
    uint256 public REFUND_SEEDING_FEE_RATE;
    /// @notice Acceleration stage refund fee rate (parts per million)
    uint256 public REFUND_ACCELERATION_FEE_RATE;

    // Custodian
    address private _custodian;

    // Constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _agentToken Agent token contract address
    /// @param _agentConfig Agent config contract address
    /// @param _initialInvestor Initial investor address
    /// @param _owner Contract owner address
    /// @return initEthIn Initial investment ETH amount
    /// @return initAgentTokenOut Initial investment Agent token amount
    function initialize(
        address _agentToken,
        address _agentConfig,
        address _initialInvestor,
        address _owner
    ) external payable initializer returns (uint256 initEthIn, uint256 initAgentTokenOut) {
        if (_owner == address(0)) revert InvalidOwner();

        __ReentrancyGuard_init();
        __Ownable_init();
        _transferOwnership(_owner);

        _agentTokenContract = IAgentToken(_agentToken);
        _agentConfigContract = IAgentConfig(_agentConfig);
        _aerodromeRouterContract = IAerodromeRouter(_agentConfigContract.getAerodromeRouter());
        _initializeParameters(_agentConfigContract);

        uint256 ethIn = msg.value;
        if (_initialInvestor != address(0) && ethIn > 0) {
            (initEthIn, initAgentTokenOut) = _processInitialInvestment(_initialInvestor, ethIn);
        }

        _updateStageIfNeeded(Stage.Genesis);
    }

    /// @notice Initialize contract parameters
    /// @param agentConfigContract Agent config contract instance
    function _initializeParameters(
        IAgentConfig agentConfigContract
    ) internal {
        AGENT_TOKEN_TOTAL_SUPPLY = agentConfigContract.getAgentTokenTotalSupply();
        INVESTMENT_UNIT = agentConfigContract.getInvestmentUnit();

        STAGE_DURATION_GENESIS_SUCCEEDED = agentConfigContract.getStageDurationGenesisSucceeded();
        STAGE_DURATION_SEEDING = agentConfigContract.getStageDurationSeeding();
        STAGE_DURATION_SEEDING_SUCCEEDED = agentConfigContract.getStageDurationSeedingSucceeded();
        STAGE_DURATION_ACCELERATION = agentConfigContract.getStageDurationAcceleration();

        SEEDING_GOAL = agentConfigContract.getSeedingGoal();
        SEEDING_MIN_INVESTORS = agentConfigContract.getSeedingMinInvestors();
        SEEDING_MAX_INDIVIDUAL_INVEST = agentConfigContract.getSeedingMaxIndividualInvest();
        SEEDING_ALLOCATION_PERCENTAGE = agentConfigContract.getSeedingAllocationPercentage();
        SEEDING_ALLOCATION = (AGENT_TOKEN_TOTAL_SUPPLY * SEEDING_ALLOCATION_PERCENTAGE) / 1_000_000;
        
        ACCELERATION_GOAL = agentConfigContract.getAccelerationGoal();
        ACCELERATION_MIN_INVESTORS = agentConfigContract.getAccelerationMinInvestors();
        ACCELERATION_MAX_INDIVIDUAL_INVEST = agentConfigContract.getAccelerationMaxIndividualInvest();
        ACCELERATION_ALLOCATION_PPERCENTAGE = agentConfigContract.getAccelerationAllocationPercentage();
        ACCELERATION_ALLOCATION = (AGENT_TOKEN_TOTAL_SUPPLY * ACCELERATION_ALLOCATION_PPERCENTAGE) / 1_000_000;
        ACCELERATION_VIRTUAL_ETH = agentConfigContract.getAccelerationVirtualETH();
        ACCELERATION_VIRTUAL_AGENT_TOKEN = agentConfigContract.getAccelerationVirtualAgentToken();
        
        AERODROME_ROUTER = agentConfigContract.getAerodromeRouter();
        AERODROME_POOL_ETH_AMOUNT = agentConfigContract.getAerodromePoolETHAmount();
        AERODROME_POOL_AGENT_TOKEN_AMOUNT = agentConfigContract.getAerodromePoolAgentTokenAmount();

        REFUND_SEEDING_FEE_RATE = agentConfigContract.getRefundSeedingFeeRate();
        REFUND_ACCELERATION_FEE_RATE = agentConfigContract.getRefundAccelerationFeeRate();
    }

    /// @notice Process initial investment
    /// @dev When the investment pool is created, there will be an initial investment from the creator's stake in Router, which will be directly counted into the seed stage
    /// @param _initialInvestor Initial investor address
    /// @param ethIn Initial investment ETH amount
    /// @return initEthIn Initial investment ETH amount
    /// @return initAgentTokenOut Initial investment Agent token amount
    function _processInitialInvestment(
        address _initialInvestor, 
        uint256 ethIn
    ) private returns (uint256 initEthIn, uint256 initAgentTokenOut) {
        _checkInvestmentLimit(ethIn, _initialInvestor);
        if (ethIn % _agentConfigContract.getInvestmentUnit() != 0) revert InvalidInvestAmount();
        
        (uint256 acceptedEthIn, uint256 agentTokenOut) = _getAgentTokenOut(Stage.Seeding, ethIn);
        if (acceptedEthIn != ethIn) revert InvestRefused();
        if (agentTokenOut == 0) revert InvalidAgentTokenOut();

        _agentTokenContract.transferAndLockSeeding(_initialInvestor, agentTokenOut);
        _recordInvestment(Stage.Seeding, ethIn, agentTokenOut, _initialInvestor);

        return (ethIn, agentTokenOut);
     }

    /// @inheritdoc IAgentPool
    function agentToken() external view override returns (address) {
        return address(_agentTokenContract);
    }

    function agentConfig() external view override returns (address) {
        return address(_agentConfigContract);
    }

    /// @inheritdoc IAgentPool
    function feeReceipient() public view override returns (address) {
        return _agentConfigContract.getFeeReceipient();
    }

    function serviceFeePeriod() public view override returns (uint256) {
        return _agentConfigContract.getServiceFeePeriod();
    }

    /// @inheritdoc IAgentPool
    function serviceFeeRate() public view override returns (uint256) {
        return _agentConfigContract.getServiceFeeRate();
    }

    /// @inheritdoc IAgentPool
    function getCurrentStage() public view override returns (Stage stage, uint256 startTime, uint256 endTime) {
        uint256 blockTimestamp = block.timestamp;

        for (uint8 i = uint8(Stage.Genesis); i <= uint8(Stage.Failed); i++) {
            stage = Stage(i);
            bool periodActive = stagePeriods[stage].startTime != 0;
            bool isInPeriod = blockTimestamp >= stagePeriods[stage].startTime && 
                (stagePeriods[stage].endTime == 0 || blockTimestamp < stagePeriods[stage].endTime);

            if (periodActive && isInPeriod) {
                return (stage, stagePeriods[stage].startTime, stagePeriods[stage].endTime);
            }
        }

        return (Stage.Genesis, 0, 0);
    }

    function _getCurrentStage() internal view returns (Stage stage) {
        (stage, ,) = getCurrentStage();
    }

    /// @inheritdoc IAgentPool
    function investmentFor(address investor) external view override returns (Investment memory) {
        return _investments[investor];
    }

    /// @dev Calculate accepted ETH amount based on current stage target amount, return accepted ETH amount
    /// @param ethIn Input ETH amount
    /// @param stageGoalTotal Current stage total target amount
    /// @return acceptedEthIn Accepted ETH amount
    function calculateAcceptableETH(
        uint256 ethIn,
        uint256 stageGoalTotal
    ) internal view returns (uint256 acceptedEthIn) {
        if (investETHTotal > stageGoalTotal) {
            acceptedEthIn = 0;
        } else if (investETHTotal + ethIn > stageGoalTotal) {
            acceptedEthIn = stageGoalTotal - investETHTotal;
        } else {
            acceptedEthIn = ethIn;
        }
    }

    /// @dev Check if investment amount exceeds single investor limit
    /// @param ethIn Input ETH amount
    /// @param recipient Investor address
    function _checkInvestmentLimit(
        uint256 ethIn,
        address recipient
    ) internal view {
        if (recipient == address(0)) revert InvalidRecipient();

        Stage currentStage = _getCurrentStage();
        if (currentStage == Stage.Seeding || currentStage == Stage.Genesis) {
            if (_investments[recipient].seedingEthIn + ethIn > SEEDING_MAX_INDIVIDUAL_INVEST) {
                revert ExceedsMaximumIndividualSeedingAmount();
            }
        } else if (currentStage == Stage.Acceleration) {
            if (_investments[recipient].accelerationEthIn + ethIn > ACCELERATION_MAX_INDIVIDUAL_INVEST) {
                revert ExceedsMaximumIndividualAccelerationAmount();
            }
        }
    }
    
    /// @inheritdoc IAgentPool
    function getAgentTokenOut(
        uint256 ethIn
    ) external view override returns (uint256 acceptedEthIn, uint256 agentTokenOut) {
        Stage currentStage = _getCurrentStage();
        (acceptedEthIn, agentTokenOut) = _getAgentTokenOut(currentStage, ethIn);
    }
    
    /// @notice Calculate Agent token amount investor can receive
    /// @dev Seeding stage price is constant, Acceleration stage price is calculated based on VIRTUAL_ETH curve
    /// @param currentStage Current stage
    /// @param ethIn Input ETH amount
    /// @return acceptedEthIn Accepted ETH amount
    /// @return agentTokenOut Received Agent token amount
    function _getAgentTokenOut(
        Stage currentStage,
        uint256 ethIn
    ) internal view returns (uint256 acceptedEthIn, uint256 agentTokenOut) {
        if (ethIn == 0) revert InvalidInvestAmount();
        if (ethIn % INVESTMENT_UNIT != 0) revert InvalidInvestmentUnit();
        if (currentStage != Stage.Seeding && currentStage != Stage.Acceleration) {
            revert InvalidStage();
        }

        if (currentStage == Stage.Seeding) {
            acceptedEthIn = calculateAcceptableETH(ethIn, SEEDING_GOAL);
            agentTokenOut = (acceptedEthIn * SEEDING_ALLOCATION) / SEEDING_GOAL;

            // If the investment amount is exactly the target amount, the remaining Agent token amount is returned
            if (investETHTotal + acceptedEthIn == SEEDING_GOAL) {
                agentTokenOut = SEEDING_ALLOCATION - investAgentTokenTotal;
            }
        } else if (currentStage == Stage.Acceleration) {
            acceptedEthIn = calculateAcceptableETH(ethIn, SEEDING_GOAL + ACCELERATION_GOAL);

            // calculate virtual ETH
            uint256 accelerationETH = investETHTotal - SEEDING_GOAL;
            uint256 currentVirtualETH = ACCELERATION_VIRTUAL_ETH + accelerationETH;
            uint256 newVirtualETH = currentVirtualETH + acceptedEthIn;

            // calculate virtual Agent Token
            uint256 accelerationAgentToken = investAgentTokenTotal - SEEDING_ALLOCATION;
            uint256 currentVirtualAgentToken = ACCELERATION_VIRTUAL_AGENT_TOKEN - accelerationAgentToken;
            uint256 newVirtualAgentToken = (ACCELERATION_VIRTUAL_ETH * ACCELERATION_VIRTUAL_AGENT_TOKEN) / newVirtualETH;

            // If the investment amount is exactly the target amount, the remaining Agent token amount is returned
            agentTokenOut = currentVirtualAgentToken - newVirtualAgentToken;
            if (investETHTotal + acceptedEthIn == SEEDING_GOAL + ACCELERATION_GOAL) {
                agentTokenOut = SEEDING_ALLOCATION + ACCELERATION_ALLOCATION - investAgentTokenTotal;
            }
        }
    }

    /// @notice Record investor investment
    /// @dev Includes investor records and updates to total ETH and Agent token amounts
    /// @param currentStage Current stage
    /// @param ethIn Input ETH amount
    /// @param agentTokenOut Received Agent token amount
    /// @param recipient Investor address
    function _recordInvestment(
        Stage currentStage,
        uint256 ethIn,
        uint256 agentTokenOut,
        address recipient
    ) internal {
        if (recipient == address(0)) revert InvalidRecipient();

        investETHTotal += ethIn;
        investAgentTokenTotal += agentTokenOut;

        if (currentStage == Stage.Seeding) {
            if (!_isSeedingInvestor[recipient]) {
                _isSeedingInvestor[recipient] = true;
                seedingInvestors.push(recipient);
            }
            _investments[recipient].seedingEthIn += ethIn;
            _investments[recipient].seedingAgentTokenOut += agentTokenOut;
        } else {
            if (!_isAccelerationInvestor[recipient]) {
                _isAccelerationInvestor[recipient] = true;
                accelerationInvestors.push(recipient);
            }
            _investments[recipient].accelerationEthIn += ethIn;
            _investments[recipient].accelerationAgentTokenOut += agentTokenOut;
        }
    }

    /// @notice Update Pool stage
    /// @dev Check conditions to update Pool stage time records
    /// @param currentStage Current stage
    /// @return newStage New stage
    function _updateStageIfNeeded(Stage currentStage) internal returns (Stage newStage) {
        uint256 blockTimestamp = block.timestamp;
        
        if (currentStage == Stage.Genesis) {
            stagePeriods[Stage.Genesis].endTime = blockTimestamp;
            stagePeriods[Stage.GenesisSucceeded].startTime = blockTimestamp;
            stagePeriods[Stage.GenesisSucceeded].endTime = blockTimestamp + STAGE_DURATION_GENESIS_SUCCEEDED;
            stagePeriods[Stage.Seeding].startTime = blockTimestamp + STAGE_DURATION_GENESIS_SUCCEEDED;
            stagePeriods[Stage.Seeding].endTime = stagePeriods[Stage.Seeding].startTime + STAGE_DURATION_SEEDING;
            stagePeriods[Stage.Failed].startTime = stagePeriods[Stage.Seeding].startTime + STAGE_DURATION_SEEDING;

            emit StageChanged(Stage.Genesis, stagePeriods[Stage.Genesis].startTime, stagePeriods[Stage.Genesis].endTime);
            emit StageChanged(Stage.GenesisSucceeded, stagePeriods[Stage.GenesisSucceeded].startTime, stagePeriods[Stage.GenesisSucceeded].endTime);
            emit StageChanged(Stage.Seeding, stagePeriods[Stage.Seeding].startTime, stagePeriods[Stage.Seeding].endTime);
            emit StageChanged(Stage.Failed, stagePeriods[Stage.Failed].startTime, stagePeriods[Stage.Failed].endTime);

            return _getCurrentStage();
        }
        else if (currentStage == Stage.Seeding) {
            if (investETHTotal >= SEEDING_GOAL) {
                stagePeriods[Stage.Seeding].endTime = blockTimestamp;
                stagePeriods[Stage.SeedingSucceeded].startTime = blockTimestamp;
                stagePeriods[Stage.SeedingSucceeded].endTime = blockTimestamp + STAGE_DURATION_SEEDING_SUCCEEDED;
                stagePeriods[Stage.Acceleration].startTime = blockTimestamp + STAGE_DURATION_SEEDING_SUCCEEDED;
                stagePeriods[Stage.Acceleration].endTime = stagePeriods[Stage.Acceleration].startTime + STAGE_DURATION_ACCELERATION;
                stagePeriods[Stage.Failed].startTime = stagePeriods[Stage.Acceleration].startTime + STAGE_DURATION_ACCELERATION;

                emit StageChanged(Stage.Seeding, stagePeriods[Stage.Seeding].startTime, stagePeriods[Stage.Seeding].endTime);
                emit StageChanged(Stage.SeedingSucceeded, stagePeriods[Stage.SeedingSucceeded].startTime, stagePeriods[Stage.SeedingSucceeded].endTime);
                emit StageChanged(Stage.Acceleration, stagePeriods[Stage.Acceleration].startTime, stagePeriods[Stage.Acceleration].endTime);
                emit StageChanged(Stage.Failed, stagePeriods[Stage.Failed].startTime, stagePeriods[Stage.Failed].endTime);

                return _getCurrentStage();
            }
        }
        else if (currentStage == Stage.Acceleration) {
            if (investETHTotal >= SEEDING_GOAL + ACCELERATION_GOAL) {
                stagePeriods[Stage.Acceleration].endTime = blockTimestamp;
                stagePeriods[Stage.Thriving].startTime = blockTimestamp;
                stagePeriods[Stage.Failed].startTime = 0;

                emit StageChanged(Stage.Acceleration, stagePeriods[Stage.Acceleration].startTime, stagePeriods[Stage.Acceleration].endTime);
                emit StageChanged(Stage.Thriving, stagePeriods[Stage.Thriving].startTime, stagePeriods[Stage.Thriving].endTime);
                emit StageChanged(Stage.Failed, stagePeriods[Stage.Failed].startTime, stagePeriods[Stage.Failed].endTime);

                return _getCurrentStage();
            }
        }
        else {
            return currentStage;
        }
    }

    /// @inheritdoc IAgentPool
    function invest(
        uint256 minAgentTokenOut,
        address recipient
    ) external payable nonReentrant onlyRouter returns (uint256 acceptedEthIn, uint256 agentTokenOut) {
        if (recipient == address(0)) revert InvalidRecipient();

        uint256 ethIn = msg.value;
        _checkInvestmentLimit(ethIn, recipient);

        Stage currentStage = _getCurrentStage();

        (acceptedEthIn, agentTokenOut) = _getAgentTokenOut(currentStage, ethIn);
        if (ethIn != acceptedEthIn) revert InvestRefused();
        if (agentTokenOut == 0) revert InvalidAgentTokenOut();
        if (agentTokenOut < minAgentTokenOut) revert InsufficientOutputAmount();

        if (currentStage == Stage.Seeding) {
            _agentTokenContract.transferAndLockSeeding(recipient, agentTokenOut);
        } else if (currentStage == Stage.Acceleration) {
            _agentTokenContract.transferAndLockAcceleration(recipient, agentTokenOut);
        }

        _recordInvestment(currentStage, ethIn, agentTokenOut, recipient);
        emit InvestmentAccepted(
            address(_agentTokenContract),
            recipient,
            ethIn,
            agentTokenOut,
            currentStage
        );
        
        Stage newStage = _updateStageIfNeeded(currentStage);
        if (newStage == Stage.Thriving) {
            _addLiquidityToAerodromePool(
                AERODROME_POOL_ETH_AMOUNT,
                AERODROME_POOL_AGENT_TOKEN_AMOUNT
            );
            _agentTokenContract.startUnlock();
        }
    }

    /// @dev Add liquidity to Aerodrome pool
    /// @param initialETHAmount Initial ETH amount
    /// @param initialAgentTokenAmount Initial Agent token amount
    /// @return amountToken Received token amount
    /// @return amountETH Received ETH amount
    /// @return liquidity Received liquidity amount
    function _addLiquidityToAerodromePool(
        uint256 initialETHAmount,
        uint256 initialAgentTokenAmount
    ) internal returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    ) {
        if (address(this).balance < initialETHAmount) {
            revert InsufficientBalance();
        }
        if (_agentTokenContract.balanceOf(address(this)) < initialAgentTokenAmount) {
            revert InsufficientBalance();
        }

        IWETH weth = _aerodromeRouterContract.weth();
        address defaultFactory = _aerodromeRouterContract.defaultFactory();

        address pool = IAerodromePoolFactory(defaultFactory).getPool(
            address(_agentTokenContract),
            address(weth),
            false);
        if (pool == address(0)) {
            pool = IAerodromePoolFactory(defaultFactory).createPool(
                address(_agentTokenContract),
                address(weth),
                false);
        }

        (uint256 token0, uint256 token1, ) = IAerodromePool(pool).getReserves();
        if (token0 != 0 && token1 != 0) revert InvalidAerodromePool();
        if (IERC20(pool).totalSupply() != 0) revert InvalidAerodromePool();

        weth.deposit{value: initialETHAmount}();
        weth.safeTransfer(pool, initialETHAmount);
        _agentTokenContract.safeTransfer(pool, initialAgentTokenAmount);
        liquidity = IAerodromePool(pool).mint(address(this));

        return (initialAgentTokenAmount, initialETHAmount, liquidity);
    }

    /// @inheritdoc IAgentPool
    function claimFeesFromAerodromePool() external returns (
        uint256 amountToken,
        uint256 amountETH
    ) {
        IWETH weth = _aerodromeRouterContract.weth();
        address defaultFactory = _aerodromeRouterContract.defaultFactory();

        address pool = IAerodromePoolFactory(defaultFactory).getPool(
            address(_agentTokenContract),
            address(weth),
            false);
        if (pool == address(0)) revert InvalidAerodromePool();

        (amountToken, amountETH) = IAerodromePool(pool).claimFees();

        return (amountToken, amountETH);
    }

    /// @notice Calculate refund amount investor can receive
    /// @dev Calculate refund amount based on current stage
    /// @param currentStage Current stage
    /// @param recipient Investor address
    /// @return refundable Whether refundable
    /// @return seedingRefund Seed stage refund amount
    /// @return accelerationRefund Acceleration stage refund amount
    /// @return seedingAgentToken Seed stage Agent token amount
    /// @return accelerationAgentToken Acceleration stage Agent token amount
    /// @return seedingRefundFee Seed stage refund fee
    /// @return accelerationRefundFee Acceleration stage refund fee
    function _refundFor(
        Stage currentStage,
        address recipient
    ) internal view returns (
        bool refundable,
        uint256 seedingRefund,
        uint256 accelerationRefund,
        uint256 seedingAgentToken,
        uint256 accelerationAgentToken,
        uint256 seedingRefundFee,
        uint256 accelerationRefundFee
    ) {
        if (recipient == address(0)) revert InvalidRecipient();

        if (currentStage != Stage.Failed) {
            return (false,0, 0, 0, 0, 0, 0);
        } else {
            seedingAgentToken = _investments[recipient].seedingAgentTokenOut;
            accelerationAgentToken = _investments[recipient].accelerationAgentTokenOut;
            seedingRefundFee = (_investments[recipient].seedingEthIn * REFUND_SEEDING_FEE_RATE) / 1_000_000;
            accelerationRefundFee = (_investments[recipient].accelerationEthIn * REFUND_ACCELERATION_FEE_RATE) / 1_000_000;
            seedingRefund = _investments[recipient].seedingEthIn - seedingRefundFee;
            accelerationRefund = _investments[recipient].accelerationEthIn - accelerationRefundFee;
            refundable = seedingRefund > 0 || accelerationRefund > 0;
        }
    }

    /// @inheritdoc IAgentPool
    function refundFor(
        address recipient
    ) external view returns (uint256){
        if (recipient == address(0)) revert InvalidRecipient();

        Stage currentStage = _getCurrentStage();
        (
            bool refundable, 
            uint256 seedingRefund, 
            uint256 accelerationRefund,
            ,,,
        ) = _refundFor(currentStage, recipient);
        if (!refundable) {
            return 0;
        }
        return seedingRefund + accelerationRefund;
    }

    /// @inheritdoc IAgentPool
    function claimRefund(address recipient) external override nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();

        Stage currentStage = _getCurrentStage();
        (
            bool refundable, 
            uint256 seedingRefund, 
            uint256 accelerationRefund, 
            uint256 seedingAgentToken,
            uint256 accelerationAgentToken,
            uint256 seedingRefundFee,
            uint256 accelerationRefundFee
        ) = _refundFor(currentStage, recipient);
        if (!refundable) revert NoRefundAvailable();

        _investments[recipient] = Investment(0, 0, 0, 0);
        
        _agentTokenContract.refundFrom(recipient);
        (bool success, ) = payable(recipient).call{value: seedingRefund + accelerationRefund}("");
        if (!success) revert EthTransferFailed();
        (success, ) = payable(feeReceipient()).call{value: seedingRefundFee + accelerationRefundFee}("");
        if (!success) revert EthTransferFailed();
        
        emit RefundClaimed(
            address(_agentTokenContract),
            recipient,
            seedingRefund,
            accelerationRefund,
            seedingAgentToken,
            accelerationAgentToken,
            seedingRefundFee,
            accelerationRefundFee
        );
    }

    function _pendingServiceFee(
        Stage currentStage,
        bool claimableOnly
    ) internal view returns (
        uint256 serviceFee,
        uint256 servicePeriodStart,
        uint256 servicePeriodEnd
    ) {
        uint256 blockTimestamp = block.timestamp;
        if (currentStage != Stage.Thriving) {
            return (0, 0, 0);
        }

        servicePeriodStart = serviceFeeClaimTime;
        if (serviceFeeClaimTime == 0) {
            servicePeriodStart = stagePeriods[Stage.Thriving].startTime;
        }
        
        uint256 timeElapsed = blockTimestamp - servicePeriodStart;
        uint256 periodCountElapsed = timeElapsed / serviceFeePeriod();
        uint256 serviceFeePerPeriod = (AGENT_TOKEN_TOTAL_SUPPLY * serviceFeeRate()) / 1_000_000;
        if (periodCountElapsed == 0) {
            return (0, 0, 0);
        }
        else {
            serviceFee = serviceFeePerPeriod * periodCountElapsed;
            servicePeriodEnd = servicePeriodStart + periodCountElapsed * serviceFeePeriod();
            if (claimableOnly) {
                uint256 tokenBalance = _agentTokenContract.balanceOf(address(this));
                if (tokenBalance < serviceFee) {
                    uint256 periodCountAvailable = tokenBalance / serviceFeePerPeriod;
                    serviceFee = serviceFeePerPeriod * periodCountAvailable;
                    servicePeriodEnd = servicePeriodStart + periodCountAvailable * serviceFeePeriod();
                }
            }
            return (serviceFee, servicePeriodStart, servicePeriodEnd);
        }
    }

    /// @inheritdoc IAgentPool
    function pendingServiceFee() external view returns (uint256) {
        Stage currentStage = _getCurrentStage();
        (
            uint256 serviceFee,
            ,
        ) = _pendingServiceFee(currentStage, false);
        return serviceFee;
    }

    /// @inheritdoc IAgentPool
    function claimServiceFee() external {
        Stage currentStage = _getCurrentStage();
        (
            uint256 serviceFee,
            uint256 servicePeriodStart,
            uint256 servicePeriodEnd
        ) = _pendingServiceFee(currentStage, true);
        if (serviceFee == 0) revert NoServiceFeeAvailable();
        if (block.timestamp < servicePeriodEnd) revert NoServiceFeeAvailable();

        address receipient = feeReceipient();
        _agentTokenContract.safeTransfer(receipient, serviceFee);
        serviceFeeClaimTime = servicePeriodEnd;

        emit ServiceFeeClaimed(
            address(_agentTokenContract),
            receipient,
            serviceFee,
            servicePeriodStart,
            servicePeriodEnd
        );
    }

    /// @inheritdoc IAgentPool
    function getSeedingInvestors(uint256 start, uint256 end) external view override returns (address[] memory) {
        if (end < start) revert InvalidStage();
        if (end >= seedingInvestors.length) revert InvalidStage();
        uint256 count = end - start + 1;
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = seedingInvestors[start + i];
        }
        return result;
    }
    
    /// @inheritdoc IAgentPool
    function getSeedingInvestorsCount() external view override returns (uint256) {
        return seedingInvestors.length;
    }
    
    /// @inheritdoc IAgentPool
    function getAccelerationInvestors(uint256 start, uint256 end) external view override returns (address[] memory) {
        if (end < start) revert InvalidStage();
        if (end >= accelerationInvestors.length) revert InvalidStage();
        uint256 count = end - start + 1;
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = accelerationInvestors[start + i];
        }
        return result;
    }
    
    /// @inheritdoc IAgentPool
    function getAccelerationInvestorsCount() external view override returns (uint256) {
        return accelerationInvestors.length;
    }

    /// @inheritdoc IAgentPool
    function custodian() external view override returns (address) {
        return _custodian;
    }

    /// @inheritdoc IAgentPool
    function setCustodian(address new_custodian) external override onlyOwner {
        if (_custodian != address(0)) revert CustodianAlreadySet();
        if (new_custodian == address(0)) revert InvalidCustodian();
        
        Stage currentStage = _getCurrentStage();
        if (currentStage != Stage.Thriving) revert NotInThrivingStage();
        
        _custodian = new_custodian;
        
        emit CustodianSet(address(_agentTokenContract), new_custodian);
    }

    /// @notice Only custodian can call
    /// @dev Check if caller is custodian
    modifier onlyCustodian() {
        if (msg.sender != _custodian) revert NotCustodian();
        _;
    }

    /// @notice Only router contract can call
    /// @dev Check if caller is router contract
    modifier onlyRouter() {
        address router = _agentConfigContract.getAgentRouter();
        if (msg.sender != router) revert NotAgentRouter();
        _;
    }

    /// @inheritdoc IAgentPool
    function withdrawFunds(
        address recipient,
        address tokenAddress,
        uint256 tokenAmount
    ) external override nonReentrant onlyCustodian {
        if (recipient == address(0)) revert InvalidRecipient();
        
        Stage currentStage = _getCurrentStage();
        if (currentStage != Stage.Thriving) revert NotInThrivingStage();

        if (tokenAddress == address(0)) {
            if (address(this).balance < tokenAmount) revert InsufficientBalance();
            (bool success, ) = recipient.call{value: tokenAmount}("");
            if (!success) revert("ETH transfer failed");
        } else {
            IERC20 token = IERC20(tokenAddress);
            if (token.balanceOf(address(this)) < tokenAmount) revert InsufficientBalance();
            token.safeTransfer(recipient, tokenAmount);
        }
        
        emit FundsWithdrawn(
            address(_agentTokenContract),
            _custodian,
            recipient,
            tokenAddress,
            tokenAmount
        );
    }

    /// @notice OpenZeppelin storage space reservation for future version upgrades to add new storage variables
    uint256[50] private __gap;
}
