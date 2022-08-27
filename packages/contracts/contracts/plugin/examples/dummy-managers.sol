// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Plugin} from "../../core/plugin/Plugin.sol";
import {PluginClones} from "../../core/plugin/PluginClones.sol";
import {IDAO} from "../../core/IDAO.sol";
import {Permission, PluginManagerSimple, PluginManagerClonable, PluginManagerUUPSUpgradeable, PluginManagerTransparent} from "../PluginManager.sol";

// RAW PLUGIN

contract DummyPlugin is Plugin {
    bytes32 public constant MULTIPLY_PERMISSION_ID = keccak256("MULTIPLY_PERMISSION");

    function execute() public auth(MULTIPLY_PERMISSION_ID) {}

    function initialize(address) public {
        // ...
    }
}

// Traditional deploy

contract DummyRawPluginManager is PluginManagerSimple {
    address private constant NO_ORACLE = address(0);

    constructor() {
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    function deploy(address dao, bytes memory data)
        public
        override
        returns (address deployedPlugin, Permission.ItemMultiTarget[] memory permissions)
    {
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(data, (address, uint256));

        address multiplyHelper = _multiplyHelper;

        // Allocate space for requested permission that will be applied on this plugin installation.
        permissions = new Permission.ItemMultiTarget[](1);

        // Encode the parameters that will be passed to initialize() on the Plugin
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address)")),
            dao
        );

        deployedPlugin = address(new ERC1967Proxy(getImplementationAddress(), initData));

        // NOTE: WE SHOULD DEFINE A FUNCTION THAT DOES setDao() under the hood => Official method.

        permissions[0] = Permission.ItemMultiTarget(
            Permission.Operation.Grant,
            dao,
            plugin,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );
    }

    function deployABI() external view virtual override returns (string memory) {
        return "(address multiplyHelper, uint num)";
    }
}

// CLONABLE

// Simple deployment

contract DummyClonablePluginManager1 is PluginManagerClonable {
    address private constant NO_ORACLE = address(0);

    function setupHook(
        address dao,
        PluginClones plugin,
        bytes memory init
    )
        public
        virtual
        override
        returns (address deployedPlugin, Permission.ItemMultiTarget[] memory permissions)
    {
        // Decode the parameters as encoded from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(init, (address, uint256));

        address multiplyHelper = _multiplyHelper;

        permissions = new Permission.ItemMultiTarget[](1);

        // Allows plugin to call execute on DAO
        permissions[0] = Permission.ItemMultiTarget(
            Permission.Operation.Grant,
            dao,
            plugin,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );
    }

    function deployABI() external view virtual override returns (string memory) {
        return "(address multiplyHelper, uint num)";
    }
}

// With helpers deployed before and after the plugin

contract DummyClonablePluginManager is PluginManagerClonable {
    MultiplyHelper public multiplyHelperBase;
    CounterV1 public counterBase;

    address private constant NO_ORACLE = address(0);

    constructor() {
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    // Overriding the init data passed to the Plugin initialization
    function setupPreHook(address dao, bytes memory initData)
        public
        returns (bytes memory pluginInitData, bytes memory setupHookInitData)
    {
        // DEPLOY A HELPER THAT NEEDS TO EXIST BEFORE THE PLUGIN
        multiplyHelper = address(multiplyHelperBase).clone();
        MultiplyHelper(multiplyHelper).initialize(dao);

        // Deploying the pugin with this data
        pluginInitData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,address)")),
            dao,
            multiplyHelper
        );

        // Params to setupHook
        setupHookInitData = abi.encode(multiplyHelper, 123, (address, uint256));
    }

    function setupHook(
        address dao,
        PluginClones deployedPlugin,
        bytes memory initData
    ) public virtual override returns (Permission.ItemMultiTarget[] memory permissions) {
        // After the plugin is deployed

        // Decode the parameters from the UI (modified by setupPreHook)
        (address _multiplyHelper, uint256 _num) = abi.decode(initData, (address, uint256));

        address multiplyHelper = _multiplyHelper;

        permissions = new Permission.ItemMultiTarget[](1);

        // DEPLOY A HELPER THAT NEEDS THE PLUGIN TO BE ALREADY CREATED
        address counterHelper = address(counterBase).clone();
        CounterHelper(counterHelper).initialize(dao, deployedPlugin);

        // Allows plugin Count to call execute on DAO
        permissions[0] = Permission.ItemMultiTarget(
            Permission.Operation.Grant,
            dao,
            plugin,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );
    }

    function deployABI() external view virtual override returns (string memory) {
        return "(address multiplyHelper, uint num)";
    }
}

// UUPS
// (similar to DummyClonablePluginManager)

// TRANSPARENT
// (similar to DummyClonablePluginManager)
