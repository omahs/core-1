// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../utils/PluginERC1967Proxy.sol";
import "../core/permission/BulkPermissionsLib.sol";
import {DAO} from "../core/DAO.sol";

/// NOTE: This is an untested code and should NOT be used in production.
/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManager {
    bytes4 public constant PLUGIN_MANAGER_INTERFACE_ID = type(PluginManager).interfaceId;

    uint256 public deploymentId;
    uint256 public helpersCount;

    mapping(uint256 => address) private daos;
    mapping(uint256 => address) private plugins;
    mapping(uint256 => address[]) internal helpers; // the array length can vary across plugin versions
    mapping(uint256 => bytes) internal initDatas;

    error InvalidLength(uint256 expected, uint256 actual);

    modifier assertAssociatedContractCount(uint256 _deploymentId) {
        if (helpersCount != helpers[_deploymentId].length) {
            revert InvalidLength(helpersCount, helpers[_deploymentId].length);
        }
        _;
    }

    // calls _install and makes sure the DAO and plugin (proxy) addresses are
    function prepareInstall(address _dao, bytes memory _data) external returns (uint256) {
        incrementDeploymentId();

        // Store the dao and deployed plugin automatically
        daos[deploymentId] = _dao;
        plugins[deploymentId] = _prepareInstall(_dao, _data);

        return deploymentId;
    }

    function prepareUpdateWithoutUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldDeploymentId,
        bytes memory _data
    ) external returns (uint256) {
        //TODO check that `oldPluginManager` is in the same `PluginRepo` and that the version bump is allowed
        // require(...);

        // TODO
        // if(oldVersion = 1.2.3)...
        // else if(oldVersion = 1.1.2)...

        incrementDeploymentId();

        // Store the dao and deployed plugin automatically
        daos[deploymentId] = _oldPluginManager.getDaoAddress(_oldDeploymentId);
        plugins[deploymentId] = _prepareUpdateWithoutUpgrade(
            _oldPluginManager,
            _oldDeploymentId,
            _data
        );

        return deploymentId;
    }

    function prepareUpdateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldDeploymentId,
        bytes memory _data
    ) external returns (uint256) {
        //TODO check that `oldPluginManager` is in the same `PluginRepo` and that the version bump is allowed
        // require(...);

        // if(version)

        incrementDeploymentId();

        // TODO make sure the plugin is UUPSUpgradable proxy

        // Store the dao and deployed plugin automatically
        daos[deploymentId] = _oldPluginManager.getDaoAddress(_oldDeploymentId);
        plugins[deploymentId] = _oldPluginManager.getPluginAddress(_oldDeploymentId); // the proxy contract

        initDatas[deploymentId] = _prepareUpdateWithUpgrade(
            _oldPluginManager,
            _oldDeploymentId,
            _data
        );

        return deploymentId;
    }

    // No deployment takes place here - so no need to return a deploymentId
    // Needed in the case that devs might want to deploy things for the uninstalltion
    function prepareUninstall(bytes memory data) internal virtual {}

    function _prepareInstall(address _dao, bytes memory _data)
        internal
        virtual
        returns (address plugin);

    /// @return plugin The address of the newly deployed logic contract
    function _prepareUpdateWithoutUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldDeploymentId,
        bytes memory _data
    ) internal virtual returns (address plugin) {}

    /// @return initData The bytes data to initialize the plugin
    function _prepareUpdateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldDeploymentId,
        bytes memory _data
    ) internal virtual returns (bytes memory initData) {}

    function getInstallPermissionOps(uint256 _deploymentId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function getUpdatePermissionOps(uint256 _deploymentId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory)
    {}

    function getUninstallPermissionOps(uint256 _deploymentId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function postInstallHook(uint256 _deploymentId) external virtual {}

    function postUpdateHook(uint256 _deploymentId) external virtual {}

    function postUninstallHook() external virtual {}

    function incrementDeploymentId() internal {
        deploymentId++;
    }

    function getDaoAddress(uint256 _deploymentId) public view returns (address) {
        return daos[_deploymentId];
    }

    function getPluginAddress(uint256 _deploymentId) public view returns (address) {
        return plugins[_deploymentId];
    }

    function getHelperAddress(uint256 _deploymentId, uint256 _index) public view returns (address) {
        return helpers[_deploymentId][_index];
    }

    function getInitData(uint256 _deploymentId) public view returns (bytes memory) {
        return initDatas[_deploymentId];
    }

    function addRelatedHelper(uint256 _deploymentId, address _helper) public {
        return helpers[_deploymentId].push(_helper);
    }

    function getImplementationAddress() public view virtual returns (address);

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param dao dao address
    /// @param logic the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    /// @return address of the proxy.
    function createProxy(
        address dao,
        address logic,
        bytes memory init
    ) internal returns (address) {
        return address(new PluginERC1967Proxy(dao, logic, init));
    }
}
