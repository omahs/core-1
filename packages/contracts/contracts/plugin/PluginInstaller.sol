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

    function install(PluginManager _pluginManager, uint256 _nonce)
        external
        installingDaoCheck(_pluginManager, _nonce)
    {
        _process(
            DAO(payable(_pluginManager.getDaoAddress(_nonce))),
            _pluginManager.getInstallPermissionOps(_nonce)
        );

        //_pluginManager.postInstallHook(); // TODO

        emit PluginInstalled();
    }

    function updateWithoutUpgrade(PluginManager _pluginManager, uint256 _nonce)
        external
        installingDaoCheck(_pluginManager, _nonce)
    {
        _update(_pluginManager, _nonce);
    }

    function _update(PluginManager _pluginManager, uint256 _nonce) internal {
        _process(
            DAO(payable(_pluginManager.getDaoAddress(_nonce))),
            _pluginManager.getUpdatePermissionOps(_nonce)
        );

        //_pluginManager.postUpdateHook(); // TODO

        emit PluginUpdated();
    }

    function updateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        PluginManager _newPluginManager,
        uint256 _newNonce
    )
        external
        installingDaoCheck(_oldPluginManager, _oldNonce)
        installingDaoCheck(_newPluginManager, _newNonce)
    {
        // Upgrade the contract
        AragonUpgradablePlugin proxy = AragonUpgradablePlugin(
            _oldPluginManager.getPluginAddress(_oldNonce)
        );

        // TODO
        /* if (!proxy.supportsInterface("UUPSUpgradable")) {
            revert PluginNotUpgradable();
        } */

        proxy.upgradeToAndCall(_newPluginManager.getPluginAddress(_newNonce), "0x");

        // Update permissions
        _update(_newPluginManager, _newNonce);
    }

    function uninstall(
        DAO _dao,
        PluginManager _pluginManager,
        uint256 _nonce
    ) external installingDaoCheck(_pluginManager, _nonce) {
        _process(_dao, _pluginManager.getUninstallPermissionOps(_nonce));

        //_pluginManager.postUninstallHook(); // TODO

        emit PluginUninstalled();
    }

    function _process(DAO _dao, BulkPermissionsLib.ItemMultiTarget[] memory _permissions)
        private
        nonReentrant
    {
        _dao.bulkOnMultiTarget(_permissions);
    }

    modifier installingDaoCheck(PluginManager _pluginManager, uint256 _nonce) {
        address installingDao = msg.sender;
        address associatedDao = _pluginManager.getDaoAddress(_nonce);

        if (installingDao != associatedDao) {
            revert WrongInstallingDao({expected: associatedDao, actual: installingDao});
        }
        _;
    }
}
