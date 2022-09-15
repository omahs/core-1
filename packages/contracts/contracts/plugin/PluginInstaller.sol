// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../core/permission/BulkPermissionsLib.sol";
import "./PluginManager.sol";

// Has ROOT_PERMISSION

contract PluginInstaller is ReentrancyGuard {
    event PluginInstalled();
    event PluginUpdated();
    event PluginUninstalled();

    uint256 private nonce;

    struct SetupStep {
        BulkPermissionsLib.ItemMultiTarget[] permissionOperations;
        address oldUpgradeablePlugin;
        address newUpgradeablePlugin;
    }

    // DAO address => nonce => permission operations
    mapping(IDAO => mapping(uint256 => BulkPermissionsLib.ItemMultiTarget[])) setupInstructions;

    function storePermissionOperations(
        IDAO dao,
        BulkPermissionsLib.ItemMultiTarget[] memory _permissionOperations
    ) external returns (uint256) {
        nonce++;
        permissionOperations[dao][nonce] = _permissionOperations;

        return nonce;
    }

    function installPlugin(
        IDAO _dao,
        PluginManager _pluginManager,
        uint256 _nonce
    ) external {
        _process(_dao, setupInstructions[_dao][_nonce].permissionOperations);

        pluginManager.postInstallHook();

        emit PluginInstalled();
    }

    function update(
        IDAO _dao,
        PluginManager _pluginManager,
        uint256 _nonce
    ) external {
        _update(_dao, _pluginManager, _nonce);
    }

    function _update(
        IDAO dao,
        PluginManager pluginManager,
        uint256 _nonce
    ) internal {
        _process(_dao, setupInstructions[_dao][_nonce].permissionOperations); // UPGRADE_PERMISSION stays on the proxy that does not change it's address

        pluginManager.postUpdateHook();

        emit PluginUpdated();
    }

    function updateWithUpgrade(
        IDAO dao,
        PluginManager pluginManager,
        uint256 _nonce
    ) external {
        // Upgrade
        AragonUpgradablePlugin oldPlugin = AragonUpgradablePlugin(
            setupInstructions[_dao][_nonce].oldPlugin
        );
        oldPlugin.upgradeToAndCall(setupInstructions[_dao][_nonce].newPlugin, "0x");

        // Update
        _update(_dao, _pluginManager, _nonce);
    }

    function uninstallPlugin(
        IDAO dao,
        PluginManager pluginManager,
        uint256 _nonce
    ) external {
        _process(_dao, setupInstructions[_dao][_nonce].permissionOperations);

        pluginManager.postUninstallHook();

        emit PluginUninstalled();
    }

    function _process(IDAO dao, BulkPermissionsLib.ItemMultiTarget[] memory permissions)
        private
        view
        nonReentrant
    {
        dao.bulkOnMultiTarget(permissions);
    }
}
