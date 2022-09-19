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

    function installPermissions(PluginManager _pluginManager, uint256 _deploymentId)
        external
        installingDaoCheck(_pluginManager, _deploymentId)
    {
        _processPermissions(
            DAO(payable(_pluginManager.getDaoAddress(_deploymentId))),
            _pluginManager.getInstallPermissionOps(_deploymentId)
        );

        //_pluginManager.postInstallHook(); // TODO

        emit PluginInstalled();
    }

    function updateWithoutUpgrade(PluginManager _pluginManager, uint256 _deploymentId)
        external
        installingDaoCheck(_pluginManager, _deploymentId)
    {
        // directly update permissions
        _updatePermissions(_pluginManager, _deploymentId);
    }

    function updatePermissionsWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldDeploymentId,
        PluginManager _newPluginManager,
        uint256 _newDeploymentId
    )
        external
        installingDaoCheck(_oldPluginManager, _oldDeploymentId)
        installingDaoCheck(_newPluginManager, _newDeploymentId)
    {
        // Upgrade the contract
        AragonUpgradablePlugin proxy = AragonUpgradablePlugin(
            _oldPluginManager.getPluginAddress(_oldDeploymentId)
        );

        // Fetch the implementation address
        address newImplementationAddr = _newPluginManager.getImplementationAddress();

        // Get potential initialization data
        bytes memory initData = _newPluginManager.getInitData(_newDeploymentId);

        // Upgrade the proxy
        if (initData.length > 0) {
            proxy.upgradeToAndCall(newImplementationAddr, initData);
        } else {
            proxy.upgradeTo(newImplementationAddr);
        }

        // Update permissions
        _updatePermissions(_newPluginManager, _newDeploymentId);
    }

    function _updatePermissions(PluginManager _pluginManager, uint256 _deploymentId) internal {
        _processPermissions(
            DAO(payable(_pluginManager.getDaoAddress(_deploymentId))),
            _pluginManager.getUpdatePermissionOps(_deploymentId)
        );

        //_pluginManager.postUpdateHook(); // TODO

        emit PluginUpdated();
    }

    function uninstallPermissions(
        DAO _dao,
        PluginManager _pluginManager,
        uint256 _deploymentId
    ) external installingDaoCheck(_pluginManager, _deploymentId) {
        _processPermissions(_dao, _pluginManager.getUninstallPermissionOps(_deploymentId));

        //_pluginManager.postUninstallHook(); // TODO

        emit PluginUninstalled();
    }

    function _processPermissions(DAO _dao, BulkPermissionsLib.ItemMultiTarget[] memory _permissions)
        private
        nonReentrant
    {
        _dao.bulkOnMultiTarget(_permissions);
    }

    modifier installingDaoCheck(PluginManager _pluginManager, uint256 _deploymentId) {
        address installingDao = msg.sender;
        address associatedDao = _pluginManager.getDaoAddress(_deploymentId);

        if (installingDao != associatedDao) {
            revert WrongInstallingDao({expected: associatedDao, actual: installingDao});
        }
        _;
    }
}
