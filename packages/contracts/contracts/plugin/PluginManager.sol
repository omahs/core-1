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
    mapping(uint256 => address[]) private helpers; // the array length can vary across plugin versions

    error InvalidLength(uint256 expected, uint256 actual);

    modifier assertAssociatedContractCount(uint256 _deploymentId) {
        if (helpersCount != helpers[_deploymentId].length) {
            revert InvalidLength(helpersCount, helpers[_deploymentId].length);
        }
        _;
    }

    function install(address _dao, bytes memory _data) external returns (uint256 id) {
        incrementNonce();

        address plugin = _install(_dao, _data);

        // Store the dao and deployed plugin automatically
        daos[deploymentId] = _dao;
        plugins[deploymentId] = plugin;

        return deploymentId;
    }

    function update(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        bytes memory _data
    ) external returns (uint256 id) {
        incrementNonce();

        address proxy = _oldPluginManager.getPluginAddress(_oldNonce);
        // TODO make sure the plugin is UUPSUpgradable proxy

        address dao = _oldPluginManager.getDaoAddress(_oldNonce);

        _update()

        daos[deploymentId] = dao;

        plugins[deploymentId] = proxy;

        return deploymentId;
    }

    function _install(address _dao, bytes memory _data) internal virtual returns (address plugin);

    function _update(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        bytes memory _data
    ) internal virtual (address plugin, bytes data) {}

    // No deployment takes place here - so no need to return a deploymentId
    function uninstall(bytes memory data) internal virtual {}

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

    function incrementNonce() internal {
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
