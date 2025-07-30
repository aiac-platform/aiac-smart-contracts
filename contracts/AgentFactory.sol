// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "./interfaces/IAgentTypes.sol";
import "./interfaces/IAgentPool.sol";
import "./interfaces/IAgentToken.sol";
import "./interfaces/IAgentFactory.sol";
import "./interfaces/IAgentRouter.sol";
import "./interfaces/IAgentConfig.sol";
import "./interfaces/IUnlockStrategy.sol";
import "./unlock/TimeBasedUnlockStrategy.sol";
import "./unlock/OracleBasedUnlockStrategy.sol";

/// @title AgentFactory
/// @notice Responsible for creating and managing Agent tokens and their corresponding investment pools, providing one-stop Agent creation services
/// @dev Implemented using upgradeable proxy pattern, supporting token and investment pool creation and management
contract AgentFactory is Initializable, OwnableUpgradeable, IAgentFactory, IAgentTypes {
    /// @notice Router contract address for creating Agents
    address public router;
    
    /// @notice Implementation address of Agent token contract
    UpgradeableBeacon public tokenBeacon;
    
    /// @notice Implementation address of Agent investment pool contract
    UpgradeableBeacon public poolBeacon;
    
    /// @notice Implementation address of time-based unlock strategy contract
    UpgradeableBeacon public timeBasedUnlockStrategyBeacon;
    
    /// @notice Implementation address of Oracle-based unlock strategy contract
    UpgradeableBeacon public oracleBasedUnlockStrategyBeacon;

    IAgentConfig public agentConfig;
    
    /// @notice Unlock strategy implementation contract upgrade event
    event UnlockStrategyImplementationUpgraded(
        address indexed strategyType,
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @dev Check if the caller is the router contract
    modifier onlyRouter() {
        if (router == address(0)) revert RouterNotSet();
        if (msg.sender != router) revert NotAuthorized();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAgentFactory
    function initialize(
        address _tokenImplementation,
        address _poolImplementation,
        address _timeBasedUnlockStrategyImplementation,
        address _oracleBasedUnlockStrategyImplementation,
        address _agentConfig,
        address _router,
        address _owner
    ) external initializer {
        if (_tokenImplementation == address(0) || _poolImplementation == address(0)) revert InvalidImplementation();

        __Ownable_init();
        _transferOwnership(_owner);
        
        agentConfig = IAgentConfig(_agentConfig);
        router = _router;
        
        tokenBeacon = new UpgradeableBeacon(_tokenImplementation, address(this));
        poolBeacon = new UpgradeableBeacon(_poolImplementation, address(this));
        timeBasedUnlockStrategyBeacon = new UpgradeableBeacon(_timeBasedUnlockStrategyImplementation, address(this));
        oracleBasedUnlockStrategyBeacon = new UpgradeableBeacon(_oracleBasedUnlockStrategyImplementation, address(this));
    }

    /// @inheritdoc IAgentFactory
    function upgradeTokenImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address oldImplementation = tokenBeacon.implementation();
        tokenBeacon.upgradeTo(newImplementation);
        emit TokenImplementationUpgraded(oldImplementation, newImplementation);
    }

    /// @notice Upgrade AgentPool implementation contract
    /// @param newImplementation New implementation contract address
    function upgradePoolImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address oldImplementation = poolBeacon.implementation();
        poolBeacon.upgradeTo(newImplementation);
        emit PoolImplementationUpgraded(oldImplementation, newImplementation);
    }
    
    /// @notice Upgrade time-based unlock strategy implementation contract
    /// @param newImplementation New implementation contract address
    function upgradeTimeBasedUnlockImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address oldImplementation = timeBasedUnlockStrategyBeacon.implementation();
        timeBasedUnlockStrategyBeacon.upgradeTo(newImplementation);
        emit UnlockStrategyImplementationUpgraded(
            address(timeBasedUnlockStrategyBeacon), 
            oldImplementation, 
            newImplementation
        );
    }
    
    /// @notice Upgrade Oracle-based unlock strategy implementation contract
    /// @param newImplementation New implementation contract address
    function upgradeOracleBasedUnlockImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address oldImplementation = oracleBasedUnlockStrategyBeacon.implementation();
        oracleBasedUnlockStrategyBeacon.upgradeTo(newImplementation);
        emit UnlockStrategyImplementationUpgraded(
            address(oracleBasedUnlockStrategyBeacon), 
            oldImplementation, 
            newImplementation
        );
    }

    /// @inheritdoc IAgentFactory
    function createAgentTokenAndPool(
        address creator,
        string memory name,
        string memory symbol,
        address initialInvestor,
        uint256 nonce
    ) external payable onlyRouter returns (address agentToken, address agentPool) {
        // Generate salt for CREATE2 deployment
        bytes32 agentSalt = keccak256(abi.encodePacked(creator, name, symbol, nonce));
        address owner = owner();
        address agentConfigAddress = address(agentConfig);
        UnlockStrategyType defaultUnlockStrategy = agentConfig.getDefaultUnlockStrategy();
        address unlockStrategy;
        
        // Deploy without initialization data, first create uninitialized BeaconProxy
        agentToken = address(new BeaconProxy{salt: agentSalt}(
            address(tokenBeacon),
            ""
        ));
        agentPool = address(new BeaconProxy{salt: agentSalt}(
            address(poolBeacon),
            ""
        ));
        if (defaultUnlockStrategy == UnlockStrategyType.TimeBased) {
            // Deploy time-based unlock strategy
            unlockStrategy = address(new BeaconProxy{salt: agentSalt}(
                address(timeBasedUnlockStrategyBeacon),
                ""
            ));
        } else if (defaultUnlockStrategy == UnlockStrategyType.OracleBased) {
            // Deploy Oracle-based unlock strategy
            unlockStrategy = address(new BeaconProxy{salt: agentSalt}(
                address(oracleBasedUnlockStrategyBeacon),
                ""
            ));
        } else {
            revert InvalidUnlockStrategy();
        }

        _initAgentTokenAndPool(_InitAgentTokenAndPoolParams(
            agentToken,
            agentPool,
            unlockStrategy,
            creator,
            name,
            symbol,
            initialInvestor,
            agentConfigAddress,
            owner,
            nonce
        ));

        return (agentToken, agentPool);
    }

    struct _InitAgentTokenAndPoolParams {
        address agentToken;
        address agentPool;
        address unlockStrategyAddress;
        address creator;
        string name;
        string symbol;
        address initialInvestor;
        address agentConfigAddress;
        address owner;
        uint256 nonce;
    }

    function _initAgentTokenAndPool(
        _InitAgentTokenAndPoolParams memory params
    ) internal {
        // Get default unlock strategy type and deploy corresponding BeaconProxy
        UnlockStrategyType unlockStrategy = agentConfig.getDefaultUnlockStrategy();
        
        if (unlockStrategy == UnlockStrategyType.TimeBased) {
            TimeBasedUnlockStrategy(params.unlockStrategyAddress).initialize(
                params.agentConfigAddress,
                params.agentToken,
                params.owner
            );
        } else if (unlockStrategy == UnlockStrategyType.OracleBased) {
            address agentOracle = agentConfig.getAgentOracle();

            OracleBasedUnlockStrategy(params.unlockStrategyAddress).initialize(
                agentOracle,
                params.agentToken,
                params.owner
            );
        } else {
            revert InvalidUnlockStrategy();
        }

        // Both addresses are obtained, now call initialization methods respectively
        IAgentToken(params.agentToken).initialize({
            _name: params.name,
            _symbol: params.symbol,
            _agentConfig: params.agentConfigAddress,
            _agentPool: params.agentPool,
            _unlockStrategy: params.unlockStrategyAddress,
            _owner: params.owner
        });
        (uint256 ethIn, uint256 agentTokenOut) = IAgentPool(params.agentPool).initialize{value: msg.value}(
            params.agentToken,
            params.agentConfigAddress,
            params.initialInvestor,
            params.owner
        );

        emit AgentCreated({
            creator: params.creator,
            agentToken: params.agentToken,
            agentPool: params.agentPool,
            agentTokenName: params.name,
            agentTokenSymbol: params.symbol,
            unlockStrategy: unlockStrategy,
            initialInvestor: params.initialInvestor,
            ethIn: ethIn,
            agentTokenOut: agentTokenOut,
            nonce: params.nonce
        });
    }

    /// @dev OpenZeppelin storage gap for future upgrades
    uint256[50] private __gap;
}
