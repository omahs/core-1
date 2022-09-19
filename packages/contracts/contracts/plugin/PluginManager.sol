// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../utils/PluginERC1967Proxy.sol";
import "../core/permission/BulkPermissionsLib.sol";
import {DAO} from "../core/DAO.sol";

/// NOTE: This is an untested code and should NOT be used in production.
/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManager {
    bytes4 public constant PLUGIN_MANAGER_INTERFACE_ID = type(PluginManager).interfaceId;

    uint256 public setupId;
    uint256 public helpersCount;

    mapping(uint256 => address) private daos;
    mapping(uint256 => address) private plugins;
    mapping(uint256 => address[]) internal helpers; // the array length can vary across plugin versions
    mapping(uint256 => bytes) internal initDatas;

    error InvalidLength(uint256 expected, uint256 actual);

    modifier assertAssociatedContractCount(uint256 _setupId) {
        if (helpersCount != helpers[_setupId].length) {
            revert InvalidLength(helpersCount, helpers[_setupId].length);
        }
        _;
    }

    function prepareInstall(address _dao, bytes memory _data) external returns (uint256) {
        incrementSetupId();

        // Store the dao and deployed plugin automatically
        daos[setupId] = _dao;
        plugins[setupId] = _prepareInstall(_dao, _data);

        return setupId;
    }

    function prepareUpdateWithoutUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        bytes memory _data
    ) external returns (uint256) {
        //TODO check that `oldPluginManager` is in the same `PluginRepo` and that the version bump is allowed
        // require(...);

        // TODO Here is the place to conduct different steps depending on the old version that we update from (that can be accessed through _oldPluginManager and the PluginRepo)
        // if(oldVersion = 1.2.3)...
        // else if(oldVersion = 1.1.2)...

        incrementSetupId();

        // Store the dao and deployed plugin automatically
        daos[setupId] = _oldPluginManager.getDaoAddress(_oldSetupId);
        plugins[setupId] = _prepareUpdateWithoutUpgrade(_oldPluginManager, _oldSetupId, _data);

        return setupId;
    }

    function prepareUpdateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        bytes memory _data
    ) external returns (uint256) {
        //TODO check that `oldPluginManager` is in the same `PluginRepo` and that the version bump is allowed
        // require(...);

        // if(version)

        incrementSetupId();

        // TODO make sure the plugin is UUPSUpgradable proxy

        // Store the dao and deployed plugin automatically
        daos[setupId] = _oldPluginManager.getDaoAddress(_oldSetupId);
        plugins[setupId] = _oldPluginManager.getPluginAddress(_oldSetupId); // the proxy contract

        initDatas[setupId] = _prepareUpdateWithUpgrade(_oldPluginManager, _oldSetupId, _data);

        return setupId;
    }

    /// @notice Stores permissions for the uninstallation.
    /// @param _oldSetupId Needed to access the contracts and permissions of the old installation / update
    function prepareUninstall(uint256 _oldSetupId, bytes memory _data) external returns (uint256) {
        incrementSetupId();

        daos[setupId] = getDaoAddress(_oldSetupId);
        plugins[setupId] = getPluginAddress(_oldSetupId);

        _prepareUninstall(_oldSetupId, _data);

        return setupId;
    }

    function _prepareUninstall(uint256 _setupId, bytes memory _data) internal virtual {}

    function _prepareInstall(address _dao, bytes memory _data)
        internal
        virtual
        returns (address plugin);

    /// @notice The updating procedure for non-upgradable contracts that the developer CAN implement. If this is the first version, it can stay empty.
    /// @param _oldPluginManager The `PluginManager` contract of the `Plugin` version to update from.
    /// @param _oldSetupId The deployment ID of the contracts in the `PluginManager` contract of the `Plugin` version to update from.
    /// @param _data Optional data needed for the update perparation.
    /// @return plugin The address of the newly deployed logic contract that the developer MUST return.
    function _prepareUpdateWithoutUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        bytes memory _data
    ) internal virtual returns (address plugin) {}

    /// @notice The updating procedure for upgradable contracts that the developer CAN implement. If this is the first version, it can stay empty.
    /// @param _oldPluginManager The `PluginManager` contract of the `Plugin` version to update from.
    /// @param _oldSetupId The deployment ID of the contracts in the `PluginManager` contract of the `Plugin` version to update from.
    /// @param _data Optional data needed for the update perparation.
    /// @return initData The bytes data that the developer MUST return to initialize the plugin after upgrading the logic.
    function _prepareUpdateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        bytes memory _data
    ) internal virtual returns (bytes memory initData) {}

    function getInstallPermissionOps(uint256 _setupId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function getUpdatePermissionOps(uint256 _setupId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory)
    {}

    function getUninstallPermissionOps(uint256 _setupId)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function postInstallHook(uint256 _setupId) external virtual {}

    function postUpdateHook(uint256 _setupId) external virtual {}

    function postUninstallHook() external virtual {}

    function incrementSetupId() internal {
        setupId++;
    }

    function getDaoAddress(uint256 _setupId) public view returns (address) {
        return daos[_setupId];
    }

    function getPluginAddress(uint256 _setupId) public view returns (address) {
        return plugins[_setupId];
    }

    function getHelperAddress(uint256 _setupId, uint256 _index) public view returns (address) {
        return helpers[_setupId][_index];
    }

    function getInitData(uint256 _setupId) public view returns (bytes memory) {
        return initDatas[_setupId];
    }

    function addRelatedHelper(uint256 _setupId, address _helper) public {
        return helpers[_setupId].push(_helper);
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
