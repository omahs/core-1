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

    function install(PluginManager _pluginManager, uint256 _deploymentId)
        external
        installingDaoCheck(_pluginManager, _deploymentId)
    {
        _process(
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
        _update(_pluginManager, _deploymentId);
    }

    function _update(PluginManager _pluginManager, uint256 _deploymentId) internal {
        _process(
            DAO(payable(_pluginManager.getDaoAddress(_deploymentId))),
            _pluginManager.getUpdatePermissionOps(_deploymentId)
        );

        //_pluginManager.postUpdateHook(); // TODO

        emit PluginUpdated();
    }

    function updateWithUpgrade(
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

        address pluignProxy = _newPluginManager.getPluginAddress(_newDeploymentId);

        bytes memory initData = _newPluginManager.update(
            _oldPluginManager,
            _oldDeploymentId,
            _data
        );

        address newImplementationAddr = _newPluginManager.getImplementationAddress();

        if (initData.length > 0) {
            pluignProxy.upgradeToAndCall(newImplementationAddr, initData);
        } else {
            pluignProxy.upgradeTo(newImplementationAddr);
        }

        // Update permissions
        _update(_newPluginManager, _newDeploymentId);
    }

    function uninstall(
        DAO _dao,
        PluginManager _pluginManager,
        uint256 _deploymentId
    ) external installingDaoCheck(_pluginManager, _deploymentId) {
        _process(_dao, _pluginManager.getUninstallPermissionOps(_deploymentId));

        //_pluginManager.postUninstallHook(); // TODO

        emit PluginUninstalled();
    }

    function _process(DAO _dao, BulkPermissionsLib.ItemMultiTarget[] memory _permissions)
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
