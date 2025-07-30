// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IUnlockStrategy.sol";
import "../interfaces/IAgentToken.sol";
import "../interfaces/IAgentTypes.sol";

/// @title OracleBasedUnlockStrategy
/// @notice Unlock strategy based on Oracle, where unlocking is triggered by Oracle and unlock ratios are set
/// @dev Oracle can add unlock events, which are stored in chronological order
contract OracleBasedUnlockStrategy is Initializable, OwnableUpgradeable, IUnlockStrategy {
    /// @notice Event emitted when an unlock event is added
    /// @param unlockTime Unlock timestamp
    /// @param seedingUnlockRatio Seed round unlock ratio (1_000_000 = 100%)
    /// @param accelerationUnlockRatio Acceleration round unlock ratio (1_000_000 = 100%)
    event UnlockEventAdded(uint256 unlockTime, uint256 seedingUnlockRatio, uint256 accelerationUnlockRatio);

    /// @dev Oracle address
    address public oracle;
    
    /// @dev Token contract address
    address public agentToken;
    
    /// @dev Unlock start time
    uint256 public unlockStartTime;
    
    /// @notice Unlock event structure
    /// @param unlockTime Unlock timestamp
    /// @param seedingUnlockRatio Seed round unlock ratio (1_000_000 = 100%)
    /// @param accelerationUnlockRatio Acceleration round unlock ratio (1_000_000 = 100%)
    struct UnlockEvent {
        uint256 unlockTime;
        uint256 seedingUnlockRatio;
        uint256 accelerationUnlockRatio;
    }
    
    /// @dev All unlock events (sorted by time)
    UnlockEvent[] public unlockEvents;
    
    /// @dev Total seed round unlock ratio
    uint256 public totalSeedingUnlockRatio;
    
    /// @dev Total acceleration round unlock ratio
    uint256 public totalAccelerationUnlockRatio;
    
    /// @dev Only Oracle can trigger unlocking
    modifier onlyOracle() {
        if (msg.sender != oracle) revert OnlyRole("oracle");
        _;
    }
    
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
    /// @param _oracle Oracle address
    /// @param _agentToken Token contract address
    /// @param _owner Contract owner
    function initialize(
        address _oracle,
        address _agentToken,
        address _owner
    ) public initializer {
        if (_oracle == address(0)) revert InvalidAddress("oracle");
        if (_agentToken == address(0)) revert InvalidAddress("token");
        
        __Ownable_init();
        _transferOwnership(_owner);

        oracle = _oracle;
        agentToken = _agentToken;
    }
    
    /// @notice Set new Oracle address
    /// @param _newOracle New Oracle address
    function setOracle(address _newOracle) external onlyOwner {
        if (_newOracle == address(0)) revert InvalidAddress("oracle");
        oracle = _newOracle;
    }
    
    /// @notice Set token contract address
    /// @param _agentToken Token contract address
    function setAgentToken(address _agentToken) external onlyOwner {
        if (_agentToken == address(0)) revert InvalidAddress("token");
        agentToken = _agentToken;
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
    
    /// @notice Oracle adds unlock event
    /// @dev No restriction on the order of addition, events will be sorted by unlockTime. However, non-sequential additions may cause UnlockRecord changes due to decimal truncation,
    /// so it is recommended to add unlock events in chronological order.
    /// @param unlockTime Unlock timestamp
    /// @param seedingUnlockRatio Seed round unlock ratio (1_000_000 = 100%)
    /// @param accelerationUnlockRatio Acceleration round unlock ratio (1_000_000 = 100%)
    function addUnlockEvent(
        uint256 unlockTime,
        uint256 seedingUnlockRatio,
        uint256 accelerationUnlockRatio
    ) external onlyOracle {
        if (unlockStartTime == 0) revert UnlockNotStarted();
        if (unlockTime < unlockStartTime) revert InvalidUnlockTime();
        
        // Check if total unlock ratio does not exceed 100%
        if (totalSeedingUnlockRatio + seedingUnlockRatio > 1_000_000) revert UnlockRatioTooHigh("seeding");
        if (totalAccelerationUnlockRatio + accelerationUnlockRatio > 1_000_000) revert UnlockRatioTooHigh("acceleration");
        
        // Update total unlock ratios
        totalSeedingUnlockRatio += seedingUnlockRatio;
        totalAccelerationUnlockRatio += accelerationUnlockRatio;
        
        // Add new unlock event (sorted by time)
        _insertUnlockEvent(UnlockEvent({
            unlockTime: unlockTime,
            seedingUnlockRatio: seedingUnlockRatio,
            accelerationUnlockRatio: accelerationUnlockRatio
        }));

        emit UnlockEventAdded(
            unlockTime,
            seedingUnlockRatio,
            accelerationUnlockRatio
        );
    }
    
    /// @inheritdoc IUnlockStrategy
    function calculateLockedBalance(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view override returns (uint256) {
        if (unlockStartTime == 0) {
            return seedingLockedAmount + accelerationLockedAmount;
        }
        
        // Calculate total unlocked ratio
        uint256 totalSeedingUnlockRatioToApply = 0;
        uint256 totalAccelerationUnlockRatioToApply = 0;
        
        // Accumulate ratios from past unlock events
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            // Only consider past unlock events
            if (block.timestamp >= unlockEvents[i].unlockTime) {
                UnlockEvent memory unlockEvt = unlockEvents[i];
                totalSeedingUnlockRatioToApply += unlockEvt.seedingUnlockRatio;
                totalAccelerationUnlockRatioToApply += unlockEvt.accelerationUnlockRatio;
            }
        }
        
        // Ensure accumulated ratio does not exceed 100%
        if (totalSeedingUnlockRatioToApply > 1_000_000) {
            totalSeedingUnlockRatioToApply = 1_000_000;
        }
        if (totalAccelerationUnlockRatioToApply > 1_000_000) {
            totalAccelerationUnlockRatioToApply = 1_000_000;
        }
        
        // Calculate unlock amount in one go
        uint256 seedingUnlockAmount = (seedingLockedAmount * totalSeedingUnlockRatioToApply) / 1_000_000;
        uint256 accelerationUnlockAmount = (accelerationLockedAmount * totalAccelerationUnlockRatioToApply) / 1_000_000;
        
        // Ensure unlock amount does not exceed locked amount
        if (seedingUnlockAmount > seedingLockedAmount) {
            seedingUnlockAmount = seedingLockedAmount;
        }
        if (accelerationUnlockAmount > accelerationLockedAmount) {
            accelerationUnlockAmount = accelerationLockedAmount;
        }
        
        // Calculate remaining locked amount
        uint256 remainingSeedingLocked = seedingLockedAmount - seedingUnlockAmount;
        uint256 remainingAccelerationLocked = accelerationLockedAmount - accelerationUnlockAmount;
        
        return remainingSeedingLocked + remainingAccelerationLocked;
    }
    
    /// @inheritdoc IUnlockStrategy
    function getNextUnlockTime() external view override returns (uint256) {
        if (unlockStartTime == 0) {
            return 0; // Unlock not started
        }
        
        // Find next pending unlock event
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            if (unlockEvents[i].unlockTime > block.timestamp) {
                return unlockEvents[i].unlockTime;
            }
        }
        
        return 0; // No future unlock events
    }
    
    /// @inheritdoc IUnlockStrategy
    function getNextUnlockAmount(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view override returns (uint256) {
        if (unlockStartTime == 0) {
            return 0; // Unlock not started
        }
        
        // Calculate total unlocked ratio
        uint256 totalSeedingUnlockRatioApplied = 0;
        uint256 totalAccelerationUnlockRatioApplied = 0;
        
        // Accumulate ratios from past unlock events
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            if (block.timestamp >= unlockEvents[i].unlockTime) {
                totalSeedingUnlockRatioApplied += unlockEvents[i].seedingUnlockRatio;
                totalAccelerationUnlockRatioApplied += unlockEvents[i].accelerationUnlockRatio;
            }
        }
        
        // Find next pending unlock event
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            if (unlockEvents[i].unlockTime > block.timestamp) {
                UnlockEvent memory nextEvent = unlockEvents[i];
                
                // Calculate total unlock ratio after next event
                uint256 newTotalSeedingRatio = totalSeedingUnlockRatioApplied + nextEvent.seedingUnlockRatio;
                uint256 newTotalAccelerationRatio = totalAccelerationUnlockRatioApplied + nextEvent.accelerationUnlockRatio;
                
                // Ensure does not exceed 100%
                if (newTotalSeedingRatio > 1_000_000) {
                    newTotalSeedingRatio = 1_000_000;
                }
                if (newTotalAccelerationRatio > 1_000_000) {
                    newTotalAccelerationRatio = 1_000_000;
                }
                
                // Calculate difference between unlock amounts before and after this event
                uint256 newSeedingUnlockAmount = (seedingLockedAmount * newTotalSeedingRatio) / 1_000_000;
                uint256 newAccelerationUnlockAmount = (accelerationLockedAmount * newTotalAccelerationRatio) / 1_000_000;
                
                uint256 currentSeedingUnlockAmount = (seedingLockedAmount * totalSeedingUnlockRatioApplied) / 1_000_000;
                uint256 currentAccelerationUnlockAmount = (accelerationLockedAmount * totalAccelerationUnlockRatioApplied) / 1_000_000;
                
                // Next actual unlock amount
                uint256 nextSeedingUnlockAmount = newSeedingUnlockAmount > currentSeedingUnlockAmount 
                    ? newSeedingUnlockAmount - currentSeedingUnlockAmount
                    : 0;
                    
                uint256 nextAccelerationUnlockAmount = newAccelerationUnlockAmount > currentAccelerationUnlockAmount
                    ? newAccelerationUnlockAmount - currentAccelerationUnlockAmount
                    : 0;
                
                return nextSeedingUnlockAmount + nextAccelerationUnlockAmount;
            }
        }
        
        return 0; // No future unlock events
    }
    
    /// @inheritdoc IUnlockStrategy
    function getUnlockRecords(
        uint256 seedingLockedAmount,
        uint256 accelerationLockedAmount
    ) external view override returns (UnlockRecord[] memory) {
        if (unlockStartTime == 0 || unlockEvents.length == 0) {
            return new UnlockRecord[](0);
        }
        
        UnlockRecord[] memory records = new UnlockRecord[](unlockEvents.length);
        uint256 recordIndex = 0;
        uint256 seedingAlreadyUnlocked = 0;
        uint256 accelerationAlreadyUnlocked = 0;
        uint256 totalSeedingUnlockRatioApplied = 0;
        uint256 totalAccelerationUnlockRatioApplied = 0;
        
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            UnlockEvent memory unlockEvt = unlockEvents[i];

            totalSeedingUnlockRatioApplied += unlockEvt.seedingUnlockRatio;
            totalAccelerationUnlockRatioApplied += unlockEvt.accelerationUnlockRatio;
            
            // Calculate unlock amount corresponding to accumulated unlock ratio
            uint256 totalSeedingUnlockAmount = (seedingLockedAmount * totalSeedingUnlockRatioApplied) / 1_000_000;
            uint256 totalAccelerationUnlockAmount = (accelerationLockedAmount * totalAccelerationUnlockRatioApplied) / 1_000_000;
            
            // Create unlock record
            records[i] = UnlockRecord({
                unlockTime: unlockEvt.unlockTime,
                seedingAmount: totalSeedingUnlockAmount - seedingAlreadyUnlocked,
                accelerationAmount: totalAccelerationUnlockAmount - accelerationAlreadyUnlocked
            });
            
            // Update already unlocked amounts
            seedingAlreadyUnlocked = totalSeedingUnlockAmount;
            accelerationAlreadyUnlocked = totalAccelerationUnlockAmount;
            
            recordIndex++;
        }
        
        return records;
    }
    
    /// @notice Get all unlock events
    /// @return Array of all unlock events
    function getAllUnlockEvents() external view returns (UnlockEvent[] memory) {
        return unlockEvents;
    }
    
    /// @notice Internal function: Insert unlock event in chronological order
    /// @param newEvent New unlock event
    function _insertUnlockEvent(UnlockEvent memory newEvent) internal {
        // Use ordered insertion method, directly insert new event at correct position
        
        // If array is empty or new event time is later than last event, append directly
        if (unlockEvents.length == 0 || newEvent.unlockTime >= unlockEvents[unlockEvents.length - 1].unlockTime) {
            unlockEvents.push(newEvent);
            return;
        }
        
        // Find correct insertion position
        uint256 insertIndex = 0;
        for (uint256 i = 0; i < unlockEvents.length; i++) {
            if (newEvent.unlockTime < unlockEvents[i].unlockTime) {
                insertIndex = i;
                break;
            }
        }
        
        // Insert new event at correct position (by moving subsequent elements and appending)
        unlockEvents.push(unlockEvents[unlockEvents.length - 1]); // First add a space at the end
        
        // Move elements from back to front
        for (uint256 i = unlockEvents.length - 1; i > insertIndex; i--) {
            unlockEvents[i] = unlockEvents[i - 1];
        }
        
        // Insert new element at correct position
        unlockEvents[insertIndex] = newEvent;
    }
    
    /// @dev OpenZeppelin storage gap for future upgrades
    uint256[50] private __gap;
} 