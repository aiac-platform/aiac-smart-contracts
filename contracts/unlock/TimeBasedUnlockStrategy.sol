// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IUnlockStrategy.sol";
import "../interfaces/IAgentConfig.sol";
import "../interfaces/IAgentToken.sol";
import "../interfaces/IAgentTypes.sol";

/// @title TimeBasedUnlockStrategy
/// @notice Time-based unlock strategy, where tokens are linearly unlocked according to preset time periods
/// @dev Linear unlock logic extracted from AgentToken
contract TimeBasedUnlockStrategy is Initializable, OwnableUpgradeable, IUnlockStrategy {
    /// @dev Linear unlock period
    uint256 public LINEAR_UNLOCK_PERIOD;
    /// @dev Number of seeding stage unlock periods
    uint256 public SEEDING_UNLOCK_PERIOD_COUNT;
    /// @dev Number of acceleration stage unlock periods
    uint256 public ACCELERATION_UNLOCK_PERIOD_COUNT;
    
    /// @dev Unlock start time
    uint256 public unlockStartTime;
    
    /// @dev Token contract address
    address public agentToken;

    /// @dev Check if caller is token contract
    modifier onlyToken() {
        if (msg.sender != agentToken) revert OnlyRole("token");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice Initialize unlock strategy contract
    /// @param _agentConfig Configuration contract address
    /// @param _agentToken Token contract address
    /// @param _owner Contract owner
    function initialize(
        address _agentConfig,
        address _agentToken,
        address _owner
    ) public initializer {
        if (_agentToken == address(0)) revert InvalidAddress("token");
        
        __Ownable_init();
        _transferOwnership(_owner);
        
        agentToken = _agentToken;
        IAgentConfig agentConfigContract = IAgentConfig(_agentConfig);
        _initializeParameters(agentConfigContract);
    }
    
    /// @notice Set token contract address
    /// @param _agentToken Token contract address
    function setAgentToken(address _agentToken) external onlyOwner {
        if (_agentToken == address(0)) revert InvalidAddress("token");
        agentToken = _agentToken;
    }
    
    /// @dev Initialize contract parameters
    /// @param agentConfigContract Configuration contract instance
    function _initializeParameters(
        IAgentConfig agentConfigContract
    ) internal {
        LINEAR_UNLOCK_PERIOD = agentConfigContract.getLinearUnlockPeriod();
        SEEDING_UNLOCK_PERIOD_COUNT = agentConfigContract.getSeedingUnlockPeriodCount();
        ACCELERATION_UNLOCK_PERIOD_COUNT = agentConfigContract.getAccelerationUnlockPeriodCount();
    }
    
    /// @inheritdoc IUnlockStrategy
    function calculateLockedBalance(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) public view override returns (uint256) {
        if (unlockStartTime == 0) {
            return seedingLockedAmount + accelerationLockedAmount;
        }
        
        uint256 blockTimestamp = block.timestamp;
        if (blockTimestamp < unlockStartTime) {
            return seedingLockedAmount + accelerationLockedAmount;
        }
        
        uint256 lastTimeElapsed = blockTimestamp - unlockStartTime;
        
        // Calculate remaining seeding stage locked amount
        uint256 remainingSeedingLocked = seedingLockedAmount;
        if (lastTimeElapsed >= SEEDING_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD) {
            remainingSeedingLocked = 0;
        } else {
            uint256 seedingLockedPeriodCount = SEEDING_UNLOCK_PERIOD_COUNT - (lastTimeElapsed / LINEAR_UNLOCK_PERIOD);
            remainingSeedingLocked = seedingLockedAmount * seedingLockedPeriodCount / SEEDING_UNLOCK_PERIOD_COUNT;
        }
        
        // Calculate remaining acceleration stage locked amount
        uint256 remainingAccelerationLocked = accelerationLockedAmount;
        if (lastTimeElapsed >= ACCELERATION_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD) {
            remainingAccelerationLocked = 0;
        } else {
            uint256 accelerationLockedPeriodCount = ACCELERATION_UNLOCK_PERIOD_COUNT - (lastTimeElapsed / LINEAR_UNLOCK_PERIOD);
            remainingAccelerationLocked = accelerationLockedAmount * accelerationLockedPeriodCount / ACCELERATION_UNLOCK_PERIOD_COUNT;
        }
        
        return remainingSeedingLocked + remainingAccelerationLocked;
    }
    
    /// @inheritdoc IUnlockStrategy
    function getNextUnlockTime() external view override returns (uint256) {
        if (unlockStartTime == 0) {
            return 0;
        }
        
        uint256 blockTimestamp = block.timestamp;
        if (blockTimestamp < unlockStartTime) {
            return unlockStartTime;
        }
        
        uint256 lastTimeElapsed = blockTimestamp - unlockStartTime;
        
        // If there are remaining periods in seeding or acceleration stage
        if (lastTimeElapsed < SEEDING_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD ||
            lastTimeElapsed < ACCELERATION_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD) {
            return unlockStartTime + (lastTimeElapsed / LINEAR_UNLOCK_PERIOD + 1) * LINEAR_UNLOCK_PERIOD;
        }
        
        return 0; // All periods have been unlocked
    }
    
    /// @inheritdoc IUnlockStrategy
    function getNextUnlockAmount(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view override returns (uint256) {
        if (unlockStartTime == 0) {
            return 0;
        }
        
        uint256 blockTimestamp = block.timestamp;
        if (blockTimestamp < unlockStartTime) {
            return 0;
        }
        
        uint256 lastTimeElapsed = blockTimestamp - unlockStartTime;
        uint256 nextAmount = 0;
        
        // Calculate next seeding stage unlock
        if (lastTimeElapsed < SEEDING_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD) {
            nextAmount += seedingLockedAmount / SEEDING_UNLOCK_PERIOD_COUNT;
        }
        
        // Calculate next acceleration stage unlock
        if (lastTimeElapsed < ACCELERATION_UNLOCK_PERIOD_COUNT * LINEAR_UNLOCK_PERIOD) {
            nextAmount += accelerationLockedAmount / ACCELERATION_UNLOCK_PERIOD_COUNT;
        }
        
        return nextAmount;
    }
    
    /// @inheritdoc IUnlockStrategy
    function getUnlockRecords(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view override returns (UnlockRecord[] memory) {
        if (unlockStartTime == 0) {
            return new UnlockRecord[](0);
        }
        
        uint256 seedingPeriods = SEEDING_UNLOCK_PERIOD_COUNT;
        uint256 accelerationPeriods = ACCELERATION_UNLOCK_PERIOD_COUNT;
        uint256 maxPeriods = seedingPeriods > accelerationPeriods ? seedingPeriods : accelerationPeriods;
        
        UnlockRecord[] memory records = new UnlockRecord[](maxPeriods);
        uint256 recordCount = 0;
        
        uint256 seedingAmountPerPeriod = seedingLockedAmount / SEEDING_UNLOCK_PERIOD_COUNT;
        uint256 accelerationAmountPerPeriod = accelerationLockedAmount / ACCELERATION_UNLOCK_PERIOD_COUNT;
        
        for (uint256 period = 0; period < maxPeriods; period++) {
            uint256 unlockTime = unlockStartTime + ((period + 1) * LINEAR_UNLOCK_PERIOD);
            uint256 seedingAmount = period < seedingPeriods ? seedingAmountPerPeriod : 0;
            uint256 accelerationAmount = period < accelerationPeriods ? accelerationAmountPerPeriod : 0;
            
            // Only add records with actual unlock amounts
            if (seedingAmount > 0 || accelerationAmount > 0) {
                records[recordCount] = UnlockRecord({
                    unlockTime: unlockTime,
                    seedingAmount: seedingAmount,
                    accelerationAmount: accelerationAmount
                });
                recordCount++;
            }
        }
        
        // Create final array with correct size and copy data
        UnlockRecord[] memory finalRecords = new UnlockRecord[](recordCount);
        for (uint256 i = 0; i < recordCount; i++) {
            finalRecords[i] = records[i];
        }
        
        return finalRecords;
    }
    
    /// @inheritdoc IUnlockStrategy
    function startUnlock() external override onlyToken {
        if (unlockStartTime != 0) revert UnlockAlreadyStarted();
        unlockStartTime = block.timestamp;
    }
    
    /// @inheritdoc IUnlockStrategy
    function isUnlockStarted() external view override returns (bool) {
        return unlockStartTime > 0;
    }
    
    /// @dev OpenZeppelin storage space reservation for future version upgrades to add new storage variables
    uint256[50] private __gap;
} 