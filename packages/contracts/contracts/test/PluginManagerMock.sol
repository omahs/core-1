// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Permission, PluginManager, PluginManagementLib} from "../plugin/PluginManager.sol";
import {PluginUUPSUpgradableV1Mock, PluginUUPSUpgradableV2Mock} from "../test/PluginUUPSUpgradableMock.sol";

// The first version of plugin manager.
contract PluginManagerMock is PluginManager {
    using PluginManagementLib for PluginManagementLib.InstallContext;

    PluginUUPSUpgradableV1Mock public helperBase;
    PluginUUPSUpgradableV1Mock public pluginBase;

    uint public constant PLUGIN_INIT_NUMBER = 15;

    address private constant NO_ORACLE = address(0);

    constructor() {
        helperBase = new PluginUUPSUpgradableV1Mock();
        pluginBase = new PluginUUPSUpgradableV1Mock();
    }

    function _getInstallInstruction(PluginManagementLib.InstallContext memory installation)
        internal
        view
        override
        returns (PluginManagementLib.InstallContext memory)
    {
        address helperAddr = installation.addHelper(address(helperBase), bytes(""));

        address pluginAddr = installation.addPlugin(
            address(pluginBase),
            abi.encodeWithSelector(bytes4(keccak256("initialize(uint256)")), PLUGIN_INIT_NUMBER)
        );

        installation.requestPermission(
            Permission.Operation.Grant,
            installation.dao,
            pluginAddr,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );

        installation.requestPermission(
            Permission.Operation.Grant,
            pluginAddr,
            helperAddr,
            NO_ORACLE,
            keccak256("SETTINGS_PERMISSION")
        );

        return installation;
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(pluginBase);
    }

    function deployABI() external view virtual override returns (string memory) {
        return "";
    }
}

// The second version of plugin manager.
contract PluginManagerV2Mock is PluginManager {
    using PluginManagementLib for PluginManagementLib.InstallContext;

    PluginUUPSUpgradableV1Mock public helperBase;
    PluginUUPSUpgradableV2Mock public pluginBase;

    address private constant NO_ORACLE = address(0);

    constructor() {
        helperBase = new PluginUUPSUpgradableV1Mock();
        // V2 version
        pluginBase = new PluginUUPSUpgradableV2Mock();
    }

    function _getInstallInstruction(PluginManagementLib.InstallContext memory installation)
        internal
        view
        override
        returns (PluginManagementLib.InstallContext memory)
    {
        address helperAddr = installation.addHelper(address(helperBase), bytes(""));

        address pluginAddr = installation.addPlugin(address(pluginBase), bytes(""));

        installation.requestPermission(
            Permission.Operation.Grant,
            installation.dao,
            pluginAddr,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );

        installation.requestPermission(
            Permission.Operation.Grant,
            pluginAddr,
            helperAddr,
            NO_ORACLE,
            keccak256("SETTINGS_PERMISSION")
        );

        return installation;
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(pluginBase);
    }

    function deployABI() external view virtual override returns (string memory) {
        return "";
    }

    function _getUpdateInstruction(
        address proxy,
        uint16[3] calldata oldVersion,
        PluginManagementLib.InstallContext memory update
    ) internal view override returns (PluginManagementLib.InstallContext memory, bytes memory initData) {
        initData = abi.encodeWithSelector(
            bytes4(keccak256("initializeV2(string)")),
            "stringExample"
        );

        address helperAddr = update.addHelper(address(helperBase), bytes(""));

        update.requestPermission(
            Permission.Operation.Revoke,
            update.dao,
            proxy,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );

        update.requestPermission(
            Permission.Operation.Grant,
            helperAddr,
            proxy,
            NO_ORACLE,
            keccak256("GRANT_PERMISSION")
        );

        return (update, initData);
    }
}
