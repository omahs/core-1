// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {PluginERC1967Proxy} from "../utils/PluginERC1967Proxy.sol";
import {BulkPermissionsLib as Permission} from "../core/permission/BulkPermissionsLib.sol";
import {Plugin} from "../core/plugin/Plugin.sol";
import {PluginClones} from "../core/plugin/PluginClones.sol";
import {PluginTransparentUpgradeable} from "../core/plugin/PluginTransparentUpgradeable.sol";
import {PluginUUPSUpgradeable} from "../core/plugin/PluginUUPSUpgradeable.sol";

interface IPluginManagerInterfaceId {
    bytes4 public constant PLUGIN_MANAGER_INTERFACE_ID;
}

interface IPluginManagerSetupHooks {
    function setupPreHook(address _dao, bytes memory init)
        public
        returns (bytes memory pluginInitData, bytes memory setupHookInitData);

    function setupHook(
        address dao,
        PluginClones plugin,
        bytes memory init
    ) public returns (Permission.ItemMultiTarget[] memory permissions);
}

interface IPluginManagerUpdateHooks {
    function updateHook(
        address dao,
        address proxy,
        uint16[3] calldata oldVersion,
        bytes memory data
    ) public returns (Permission.ItemMultiTarget[] memory permissions);
}

// CONTRACTS

/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManagerSimple is IPluginManagerInterfaceId {
    constructor() {
        PLUGIN_MANAGER_INTERFACE_ID = type(PluginManagerSimple).interfaceId;
    }

    /// @notice the function dev has to override/implement for the plugin deployment.
    /// @param dao dao address where plugin will be installed to in the end.
    /// @param data the ABI encoded data that deploy needs for its work.
    /// @return plugin the plugin address
    /// @return permissions array of permissions that will be applied through plugin installations.
    function deploy(address dao, bytes memory data)
        public
        virtual
        returns (Plugin deployedPlugin, Permission.ItemMultiTarget[] memory permissions);

    /// @notice the ABI in string format that deploy function needs to use.
    /// @return ABI in string format.
    function getDeployABI() external view virtual returns (string memory);
}

abstract contract PluginManagerClonable is IPluginManagerInterfaceId, IPluginManagerSetupHooks {
    constructor() {
        PLUGIN_MANAGER_INTERFACE_ID = type(PluginManagerClonable).interfaceId;
    }

    function setupPreHook(address _dao, bytes memory init)
        public
        returns (bytes memory pluginInitData, bytes memory setupHookInitData)
    {
        // By default, it bridges data to the plugin initialize() and to the setupHook()
        pluginInitData = init;
        setupHookInitData = init;

        // The developer can override this function and return a different init function call, if needed
    }

    /// @notice An overridable function to complete the setup, deploy internal helpers, and return the requested permissions.
    /// @param dao dao address where plugin will be installed to in the end.
    /// @param deployedPlugin The instance of the already deployed plugin
    /// @param initData the ABI encoded data that deploy needs for its work.
    /// @return The array of requested permissions. Note: Only the `deployedPlugin` can hold permissions on the DAO.
    function setupHook(
        address dao,
        PluginTransparentUpgradeable deployedPlugin,
        bytes memory initData
    ) public returns (Permission.ItemMultiTarget[] memory permissions) {}

    /// @notice the plugin's base implementation address proxies need to delegate calls.
    /// @return address of the base contract address.
    function getImplementationAddress() public view virtual returns (address);

    /// @notice the ABI in string format that deploy function needs to use.
    /// @return ABI in string format.
    function getDeployABI() external view virtual returns (string memory);
}

abstract contract PluginManagerUUPSUpgradeable is
    IPluginManagerInterfaceId,
    IPluginManagerSetupHooks,
    IPluginManagerUpdateHooks
{
    constructor() {
        PLUGIN_MANAGER_INTERFACE_ID = type(PluginManagerUUPSUpgradeable).interfaceId;
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param dao dao address
    /// @param implementationAddress the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    /// @return address of the proxy.
    function createProxy(
        address dao,
        address implementationAddress,
        bytes memory init
    ) internal returns (address) {
        return address(new PluginERC1967Proxy(dao, implementationAddress, init));
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param pluginProxy proxy address
    /// @param implementationAddress the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    function upgradeProxy(
        address pluginProxy,
        address implementationAddress,
        bytes memory init
    ) internal {
        // TODO: shall we implement this ?
    }

    function setupPreHook(address dao, bytes memory initData)
        public
        returns (bytes memory pluginInitData, bytes memory setupHookInitData)
    {
        // By default, it bridges data to the plugin initialize() and to the setupHook()
        pluginInitData = initData;
        setupHookInitData = initData;

        // The developer can override this function and return a different init function call, if needed
    }

    /// @notice An overridable function to complete the setup, deploy internal helpers, and return the requested permissions.
    /// @param dao dao address where plugin will be installed to in the end.
    /// @param deployedPlugin The instance of the already deployed plugin
    /// @param initData the ABI encoded data that deploy needs for its work.
    /// @return The array of requested permissions. Note: Only the `deployedPlugin` can hold permissions on the DAO.
    function setupHook(
        address dao,
        PluginTransparentUpgradeable deployedPlugin,
        bytes memory initData
    ) public returns (Permission.ItemMultiTarget[] memory permissions) {}

    /// @notice the function dev has to override/implement for the plugin update.
    /// @param dao proxy address
    /// @param pluginProxy proxy address
    /// @param oldVersion the version plugin is updating from.
    /// @param initData the other data that deploy needs.
    /// @return permissions array of permissions that will be applied through plugin installations.
    function updateHook(
        address dao,
        address pluginProxy,
        uint16[3] calldata oldVersion,
        bytes memory initData
    ) public virtual returns (Permission.ItemMultiTarget[] memory permissions) {}

    /// @notice the plugin's base implementation address proxies need to delegate calls.
    /// @return address of the base contract address.
    function getImplementationAddress() public view virtual returns (address);

    /// @notice the ABI in string format that deploy function needs to use.
    /// @return ABI in string format.
    function getDeployABI() external view virtual returns (string memory);

    /// @notice The ABI in string format that update function needs to use.
    /// @dev Not required to be overriden as there might be no update at all by dev.
    /// @return ABI in string format.
    function getUpdateABI() external view virtual returns (string memory) {}
}

abstract contract PluginManagerTransparent is
    IPluginManagerInterfaceId,
    IPluginManagerSetupHooks,
    IPluginManagerUpdateHooks
{
    constructor() {
        PLUGIN_MANAGER_INTERFACE_ID = type(PluginManagerTransparent).interfaceId;
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param dao dao address
    /// @param implementationAddress the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    /// @return address of the proxy.
    function createProxy(
        address dao,
        address implementationAddress,
        bytes memory init
    ) internal returns (address) {
        return address(new PluginERC1967Proxy(dao, implementationAddress, init));
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param pluginProxy proxy address
    /// @param implementationAddress the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    function upgradeProxy(
        address pluginProxy,
        address implementationAddress,
        bytes memory init
    ) internal {
        // TODO: shall we implement this ?
    }

    function setupPreHook(address dao, bytes memory initData)
        public
        returns (bytes memory pluginInitData, bytes memory setupHookInitData)
    {
        // By default, it bridges data to the plugin initialize() and to the setupHook()
        pluginInitData = initData;
        setupHookInitData = initData;

        // The developer can override this function and return a different init function call, if needed
    }

    /// @notice An overridable function to complete the setup, deploy internal helpers, and return the requested permissions.
    /// @param dao dao address where plugin will be installed to in the end.
    /// @param deployedPlugin The instance of the already deployed plugin
    /// @param initData the ABI encoded data that deploy needs for its work.
    /// @return The array of requested permissions. Note: Only the `deployedPlugin` can hold permissions on the DAO.
    function setupHook(
        address dao,
        PluginTransparentUpgradeable deployedPlugin,
        bytes memory initData
    ) public returns (Permission.ItemMultiTarget[] memory permissions) {}

    /// @notice the function dev has to override/implement for the plugin update.
    /// @param dao proxy address
    /// @param pluginProxy proxy address
    /// @param oldVersion the version plugin is updating from.
    /// @param initData the other data that deploy needs.
    /// @return permissions array of permissions that will be applied through plugin installations.
    function updateHook(
        address dao,
        address pluginProxy,
        uint16[3] calldata oldVersion,
        bytes memory initData
    ) public virtual returns (Permission.ItemMultiTarget[] memory permissions) {}

    /// @notice the plugin's base implementation address proxies need to delegate calls.
    /// @return address of the base contract address.
    function getImplementationAddress() public view virtual returns (address);

    /// @notice the ABI in string format that deploy function needs to use.
    /// @return ABI in string format.
    function getDeployABI() external view virtual returns (string memory);

    /// @notice The ABI in string format that update function needs to use.
    /// @dev Not required to be overriden as there might be no update at all by dev.
    /// @return ABI in string format.
    function getUpdateABI() external view virtual returns (string memory) {}
}
