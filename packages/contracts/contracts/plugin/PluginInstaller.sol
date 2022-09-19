// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../core/permission/BulkPermissionsLib.sol";
import "./PluginManager.sol";
import "../core/DAO.sol";
import {AragonUpgradablePlugin} from "../core/plugin/AragonUpgradablePlugin.sol";

contract PluginInstaller is ReentrancyGuard {
    event PluginInstalled();
    event PluginUpdated();
    event PluginUninstalled();

    error WrongInstallingDao(address expected, address actual);
    error PluginNotUpgradable();

    function installPermissions(PluginManager _pluginManager, uint256 _setupId)
        external
        installingDaoCheck(_pluginManager, _setupId)
    {
        _processPermissions(
            DAO(payable(_pluginManager.getDaoAddress(_setupId))),
            _pluginManager.getInstallPermissionOps(_setupId)
        );

        //_pluginManager.postInstallHook(); // TODO

        emit PluginInstalled();
    }

    function updateWithoutUpgrade(PluginManager _pluginManager, uint256 _setupId)
        external
        installingDaoCheck(_pluginManager, _setupId)
    {
        // directly update permissions
        _updatePermissions(_pluginManager, _setupId);
    }

    function updatePermissionsWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        PluginManager _newPluginManager,
        uint256 _newSetupId
    )
        external
        installingDaoCheck(_oldPluginManager, _oldSetupId)
        installingDaoCheck(_newPluginManager, _newSetupId)
    {
        // Upgrade the contract
        AragonUpgradablePlugin proxy = AragonUpgradablePlugin(
            _oldPluginManager.getPluginAddress(_oldSetupId)
        );

        // Fetch the implementation address
        address newImplementationAddr = _newPluginManager.getImplementationAddress();

        // Get potential initialization data
        bytes memory initData = _newPluginManager.getInitData(_newSetupId);

        // Upgrade the proxy
        if (initData.length > 0) {
            proxy.upgradeToAndCall(newImplementationAddr, initData);
        } else {
            proxy.upgradeTo(newImplementationAddr);
        }

        // Update permissions
        _updatePermissions(_newPluginManager, _newSetupId);
    }

    function _updatePermissions(PluginManager _pluginManager, uint256 _setupId) internal {
        _processPermissions(
            DAO(payable(_pluginManager.getDaoAddress(_setupId))),
            _pluginManager.getUpdatePermissionOps(_setupId)
        );

        //_pluginManager.postUpdateHook(); // TODO

        emit PluginUpdated();
    }

    function uninstallPermissions(
        DAO _dao,
        PluginManager _pluginManager,
        uint256 _setupId
    ) external installingDaoCheck(_pluginManager, _setupId) {
        _processPermissions(_dao, _pluginManager.getUninstallPermissionOps(_setupId));

        //_pluginManager.postUninstallHook(); // TODO

        emit PluginUninstalled();
    }

    function _processPermissions(DAO _dao, BulkPermissionsLib.ItemMultiTarget[] memory _permissions)
        private
        nonReentrant
    {
        _dao.bulkOnMultiTarget(_permissions);
    }

    modifier installingDaoCheck(PluginManager _pluginManager, uint256 _setupId) {
        address installingDao = msg.sender;
        address associatedDao = _pluginManager.getDaoAddress(_setupId);

        if (installingDao != associatedDao) {
            revert WrongInstallingDao({expected: associatedDao, actual: installingDao});
        }
        _;
    }
}
