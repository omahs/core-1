// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {PermissionLib} from "../../core/permission/PermissionLib.sol";
import {PluginUUPSUpgradeable} from "../../core/plugin/PluginUUPSUpgradeable.sol";
import {IPlugin} from "../../core/plugin/IPlugin.sol";
import {IPluginSetup} from "../IPluginSetup.sol";
import {DaoAuthorizable} from "../../core/component/dao-authorizable/DaoAuthorizable.sol";
import {DAO, IDAO} from "../../core/DAO.sol";
import {PluginRepoRegistry} from "../../registry/PluginRepoRegistry.sol";
import {PluginSetup} from "../PluginSetup.sol";
import {PluginRepo} from "../PluginRepo.sol";
import {isValidBumpLoose, BumpInvalid} from "../SemanticVersioning.sol";
import {PluginSetupRef, aHash, hHash, pHash, _getSetupId, _getPluginId} from "./utils/Common.sol";

/// @title PluginSetupProcessor
/// @author Aragon Association - 2022
/// @notice This contract processes the preparation and application of plugin setups (installation, update, uninstallation) on behalf of a requesting DAO.
/// @dev This contract is temporarily granted the `ROOT_PERMISSION_ID` permission on the applying DAO and therefore is highly security critical.
contract PluginSetupProcessor is DaoAuthorizable {
    using ERC165Checker for address;

    /// @notice The ID of the permission required to call the `applyInstallation` function.
    bytes32 public constant APPLY_INSTALLATION_PERMISSION_ID =
        keccak256("APPLY_INSTALLATION_PERMISSION");

    /// @notice The ID of the permission required to call the `applyUpdate` function.
    bytes32 public constant APPLY_UPDATE_PERMISSION_ID = keccak256("APPLY_UPDATE_PERMISSION");

    /// @notice The ID of the permission required to call the `applyUninstallation` function.
    bytes32 public constant APPLY_UNINSTALLATION_PERMISSION_ID =
        keccak256("APPLY_UNINSTALLATION_PERMISSION");

    struct PluginInformation {
        uint256 blockNumber;
        bytes32 currentSetupId;
        mapping(bytes32 => uint256) setupIds;
    }

    mapping(bytes32 => PluginInformation) private states;

    /// @notice The struct containing the parameters for the `prepareInstallation` function.
    struct PrepareInstall {
        PluginSetupRef pluginSetupRef;
        bytes data;
    }

    /// @notice The struct containing the parameters for the `applyInstallation` function.
    struct ApplyInstall {
        PluginSetupRef pluginSetupRef;
        address plugin;
        PermissionLib.ItemMultiTarget[] permissions;
        bytes32 helpersHash;
        IDAO.Action[] actions;
    }

    /// @notice The struct containing the parameters for the `prepareUpdate` function.
    struct PrepareUpdate {
        PluginRepo.Tag currentVersionTag;
        PluginRepo.Tag newVersionTag;
        PluginRepo pluginSetupRepo;
        IPluginSetup.SetupPayload setupPayload;
    }

    /// @notice The struct containing the parameters for the `applyUpdate` function.
    struct ApplyUpdate {
        address plugin;
        PluginSetupRef pluginSetupRef;
        bytes initData;
        PermissionLib.ItemMultiTarget[] permissions;
        bytes32 helpersHash;
        IDAO.Action[] actions;
    }

    /// @notice The struct containing the parameters for the `prepareUninstallation` function.
    struct PrepareUninstall {
        PluginSetupRef pluginSetupRef;
        IPluginSetup.SetupPayload setupPayload;
        bytes32 permissionsHash;
    }

    /// @notice The struct containing the parameters for the `applyInstallation` function.
    struct ApplyUninstall {
        address plugin;
        PluginSetupRef pluginSetupRef;
        address[] currentHelpers;
        PermissionLib.ItemMultiTarget[] permissions;
        bytes32 helpersHash;
    }

    /// @notice The plugin repo registry listing the `PluginRepo` contracts versioning the `PluginSetup` contracts.
    PluginRepoRegistry public repoRegistry;

    /// @notice Thrown if a setup is unauthorized for the associated DAO.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param caller The address (EOA or contract) that requested the application of a setup on the associated DAO.
    /// @param permissionId The permission identifier.
    error SetupApplicationUnauthorized(address dao, address caller, bytes32 permissionId);

    /// @notice Thrown if a plugin is not upgradeable.
    /// @param plugin The address of the plugin contract.
    error PluginNonupgradeable(address plugin);

    /// @notice Thrown if the upgrade of a plugin proxy failed.
    /// @param proxy The address of the UUPSUpgradeable proxy.
    /// @param implementation The address of the implementation contract.
    /// @param initData The initialization data to be passed to the upgradeable plugin contract via `upgradeToAndCall`.
    error PluginProxyUpgradeFailed(address proxy, address implementation, bytes initData);

    /// @notice Thrown if a contract does not support the `IPlugin` interface.
    /// @param plugin The address of the contract.
    error IPluginNotSupported(address plugin);

    /// @notice Thrown if two permissions hashes obtained via [`getPermissionsHash`](#private-function-`getPermissionsHash`) don't match.
    error PermissionsHashMismatch();

    /// @notice Thrown if two helpers hashes obtained via  [`getHelpersHash`](#private-function-`getHelpersHash`) don't match.
    error HelpersHashMismatch();

    /// @notice Thrown if a plugin repository does not exist on the plugin repo registry.
    error PluginRepoNonexistent();

    /// @notice Thrown if a plugin setup is not prepared.
    /// @param setupId The abi encoded hash of versionTag & permissions & helpers.
    error SetupNotPrepared(bytes32 setupId);

    /// @notice Thrown if a plugin setup was already prepared.
    /// @param setupId The abi encoded hash of versionTag & permissions & helpers.
    error SetupAlreadyPrepared(bytes32 setupId);

    /// @notice Thrown if a plugin setup is not applied.
    error SetupNotApplied();

    /// @notice Thrown if a plugin setup was already prepared. This is done in case the `PluginSetup` contract is malicios and always/sometime returns the same addresss.
    error SetupAlreadyApplied();

    /// @notice Thrown when the update version is invalid.
    /// @param currentVersionTag The current version of the plugin from which it updates.
    /// @param newVersionTag The new version of the plugin to which it updates.
    error UpdateVersionInvalid(PluginRepo.Tag currentVersionTag, PluginRepo.Tag newVersionTag);

    /// @notice Thrown when plugin is already installed and one tries to prepare or apply install on it.
    error PluginAlreadyInstalled();

    /// @notice Thrown when user's arguments for the apply function don't match the currently applied setupId.
    /// @param currentSetupId The current setup id to which user's preparation setup should match to.
    /// @param setupId The user's preparation setup id.
    error InvalidSetupId(bytes32 currentSetupId, bytes32 setupId);

    /// @notice Thrown when setup is no longer eligible for the `apply`. This could happen if another prepared setup was chosen for the apply.
    /// @param setupId The prepared setup id from the `prepareInstallation`, `prepareUpdate` or `prepareUninstallation`.
    error SetupNotEligible(bytes32 setupId);

    /// @notice Emitted with a prepared plugin installation to store data relevant for the application step.
    /// @param sender The sender that prepared the plugin installation.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    /// @param data The `bytes` encoded data containing the input parameters for the installation as specified in the `prepareInstallationDataABI()` function in the `pluginSetup` setup contract.
    /// @param plugin The address of the plugin contract.
    /// @param helpers The address array of all helpers (contracts or EOAs) that were prepared for the plugin to be installed.
    /// @param permissions The list of multi-targeted permission operations to be applied to the installing DAO.
    event InstallationPrepared(
        address indexed sender,
        address indexed dao,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag,
        bytes data,
        address plugin,
        address[] helpers,
        PermissionLib.ItemMultiTarget[] permissions
    );

    /// @notice Emitted after a plugin installation was applied.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param plugin The address of the plugin contract.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    event InstallationApplied(
        address indexed dao,
        address indexed plugin,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag
    );

    /// @notice Emitted with a prepared plugin update to store data relevant for the application step.
    /// @param sender The sender that prepared the plugin installation.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    /// @param data The `bytes` encoded data containing the input parameters for the installation as specified in the `prepareInstallationDataABI()` function in the `pluginSetup` setup contract.
    /// @param plugin The address of the plugin contract.
    /// @param updatedHelpers The address array of all helpers (contracts or EOAs) that were prepared for the plugin update.
    /// @param permissions The list of multi-targeted permission operations to be applied to the installing DAO.
    /// @param initData The initialization data to be passed to the upgradeable plugin contract.
    event UpdatePrepared(
        address indexed sender,
        address indexed dao,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag,
        bytes data,
        address plugin,
        address[] updatedHelpers,
        PermissionLib.ItemMultiTarget[] permissions,
        bytes initData
    );

    /// @notice Emitted after a plugin update was applied.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param plugin The address of the plugin contract.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    event UpdateApplied(
        address indexed dao,
        address indexed plugin,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag
    );

    /// @notice Emitted with a prepared plugin uninstallation to store data relevant for the application step.
    /// @param sender The sender that prepared the plugin uninstallation.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    /// @param data The `bytes` encoded data containing the input parameters for the uninstallation as specified in the `prepareUninstallationDataABI()` function in the `pluginSetup` setup contract.
    /// @param plugin The address of the plugin contract.
    /// @param currentHelpers The address array of all helpers (contracts or EOAs) that were prepared for the plugin to be installed.
    /// @param permissions The list of multi-targeted permission operations to be applied to the installing DAO.
    event UninstallationPrepared(
        address indexed sender,
        address indexed dao,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag,
        bytes data,
        address plugin,
        address[] currentHelpers,
        PermissionLib.ItemMultiTarget[] permissions
    );

    /// @notice Emitted after a plugin installation was applied.
    /// @param dao The address of the dao to which the plugin belongs.
    /// @param plugin The address of the plugin contract.
    /// @param pluginSetupRepo The repository storing the `PluginSetup` contracts of all versions of a plugin.
    /// @param versionTag The version tag of the plugin to used for install preparation.
    event UninstallationApplied(
        address indexed dao,
        address indexed plugin,
        PluginRepo indexed pluginSetupRepo,
        PluginRepo.Tag versionTag
    );

    /// @notice A modifier to check if a caller has the permission to apply a prepared setup.
    /// @param _dao The address of the DAO.
    /// @param _permissionId The permission identifier.
    modifier canApply(address _dao, bytes32 _permissionId) {
        _canApply(_dao, _permissionId);
        _;
    }

    /// @notice Constructs the plugin setup processor by setting the managing DAO and the associated plugin repo registry.
    /// @param _managingDao The DAO managing the plugin setup processors permissions.
    /// @param _repoRegistry The plugin repo registry contract.
    constructor(IDAO _managingDao, PluginRepoRegistry _repoRegistry) DaoAuthorizable(_managingDao) {
        repoRegistry = _repoRegistry;
    }

    /// @notice Prepares the installation of a plugin.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `prepareInstallation` function.
    /// @return plugin The prepared plugin contract address.
    /// @return preparedDependency TOD:GIORGI
    function prepareInstallation(address _dao, PrepareInstall calldata _params)
        external
        returns (address plugin, IPluginSetup.PreparedDependency memory preparedDependency)
    {
        PluginRepo pluginSetupRepo = _params.pluginSetupRef.pluginSetupRepo;

        // Check that the plugin repository exists on the plugin repo registry.
        if (!repoRegistry.entries(address(pluginSetupRepo))) {
            revert PluginRepoNonexistent();
        }

        // reverts if not found
        PluginRepo.Version memory version = pluginSetupRepo.getVersion(
            _params.pluginSetupRef.versionTag
        );

        // Prepare the installation
        (plugin, preparedDependency) = PluginSetup(version.pluginSetup).prepareInstallation(
            _dao,
            _params.data
        );

        bytes32 pluginId = _getPluginId(_dao, plugin);

        bytes32 setupId = _getSetupId(
            _params.pluginSetupRef,
            pHash(preparedDependency.permissions),
            hHash(preparedDependency.helpers),
            aHash(preparedDependency.actions),
            bytes("")
        );

        PluginInformation storage pluginInformation = states[pluginId];

        // Allow calling `prepareInstallation` only when
        // plugin was uninstalled or never been installed before.
        if (pluginInformation.currentSetupId != bytes32(0)) {
            revert PluginAlreadyInstalled();
        }

        // Only allow to prepare if setupId has not been prepared before.
        // NOTE that if plugin was uninstalled, the same setupId can still
        // be prepared as blockNumber would end up being higher than setupId's blockNumber.
        if(pluginInformation.blockNumber < pluginInformation.setupIds[setupId]) {
            revert SetupAlreadyPrepared(setupId);
        }

        pluginInformation.setupIds[setupId] = block.number;

        return (plugin, preparedDependency);
    }

    /// @notice Applies the permissions of a prepared installation to a DAO.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `applyInstallation` function.
    function applyInstallation(address _dao, ApplyInstall calldata _params)
        external
        canApply(_dao, APPLY_INSTALLATION_PERMISSION_ID)
    {
        bytes32 pluginId = _getPluginId(_dao, _params.plugin);

        PluginInformation storage pluginInformation = states[pluginId];

        bytes32 setupId = _getSetupId(
            _params.pluginSetupRef,
            pHash(_params.permissions),
            _params.helpersHash,
            aHash(_params.actions),
            bytes("")
        );

        // Allow calling `applyInstallation` only when
        // plugin was uninstalled or never been installed before.
        if (pluginInformation.currentSetupId != bytes32(0)) {
            revert PluginAlreadyInstalled();
        }

        // If the plugin block number exceeds the setupId preparation block number,
        // This means applyInstallation was already called on another setupId
        // and all the rest setupIds should become idle or setupId is not prepared before.
        if (pluginInformation.blockNumber >= pluginInformation.setupIds[setupId]) {
            revert SetupNotEligible(setupId);
        }

        bytes32 newSetupId = _getSetupId(
            _params.pluginSetupRef,
            bytes32(0),
            _params.helpersHash,
            bytes32(0),
            bytes("")
        );

        pluginInformation.currentSetupId = newSetupId;
        pluginInformation.blockNumber = block.number;

        _executeOnDAO(_dao, setupId, _params.permissions, _params.actions);
    }

    /// @notice Prepares the update of an UUPS upgradeable plugin.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `prepareUpdate` function.
    /// @return permissions The list of multi-targeted permission operations to be applied to the updating DAO.
    /// @return initData The initialization data to be passed to upgradeable contracts when the update is applied
    /// @dev The list of `_currentHelpers` has to be specified in the same order as they were returned from previous setups preparation steps (the latest `prepareInstallation` or `prepareUpdate` step that has happend) on which the update is prepared for
    function prepareUpdate(address _dao, PrepareUpdate calldata _params)
        external
        returns (PermissionLib.ItemMultiTarget[] memory, bytes memory)
    {
        if (
            _params.currentVersionTag.release != _params.newVersionTag.release ||
            _params.currentVersionTag.build <= _params.newVersionTag.build
        ) {
            revert UpdateVersionInvalid({
                currentVersionTag: _params.currentVersionTag,
                newVersionTag: _params.newVersionTag
            });
        }

        // // Check that plugin is `PluginUUPSUpgradable`.
        if (!_params.setupPayload.plugin.supportsInterface(type(IPlugin).interfaceId)) {
            revert IPluginNotSupported({plugin: _params.setupPayload.plugin});
        }
        if (IPlugin(_params.setupPayload.plugin).pluginType() != IPlugin.PluginType.UUPS) {
            revert PluginNonupgradeable({plugin: _params.setupPayload.plugin});
        }

        PluginRepo.Version memory currentVersion = _params.pluginSetupRepo.getVersion(
            _params.currentVersionTag
        );

        PluginRepo.Version memory newVersion = _params.pluginSetupRepo.getVersion(
            _params.newVersionTag
        );

        if (currentVersion.pluginSetup == newVersion.pluginSetup) {
            // revert plugin setups can't be the same(pointless)
        }

        bytes32 pluginId = _getPluginId(_dao, _params.setupPayload.plugin);

        PluginInformation storage pluginInformation = states[pluginId];

        bytes32 setupId = _getSetupId(
            PluginSetupRef(_params.currentVersionTag, _params.pluginSetupRepo),
            bytes32(0),
            hHash(_params.setupPayload.currentHelpers),
            bytes32(0),
            bytes("")
        );

        // The following check implicitly confirms that plugin
        // is currently installed. Otherwise, currentSetupId wouldn't be set.
        if (pluginInformation.currentSetupId != setupId) {
            revert InvalidSetupId({
                currentSetupId: pluginInformation.currentSetupId,
                setupId: setupId
            });
        }

        // Prepare the update.
        (
            bytes memory initData,
            IPluginSetup.PreparedDependency memory preparedDependency
        ) = PluginSetup(newVersion.pluginSetup).prepareUpdate(
                _dao,
                _params.currentVersionTag.build,
                _params.setupPayload
            );

        bytes32 newSetupId = _getSetupId(
            PluginSetupRef(_params.newVersionTag, _params.pluginSetupRepo),
            pHash(preparedDependency.permissions),
            hHash(preparedDependency.helpers),
            aHash(preparedDependency.actions),
            initData
        );

        // Only allow to prepare if setupId has not been prepared before.
        // Note that the following check ensures that the same setupId can be prepared
        // once again if the plugin was uninstalled and then installed.. 
        if(pluginInformation.blockNumber < pluginInformation.setupIds[newSetupId]) {
            revert SetupAlreadyPrepared(setupId);
        }

        pluginInformation.setupIds[newSetupId] = block.number;

        return (preparedDependency.permissions, initData);
    }

    /// @notice Applies the permissions of a prepared update of an UUPS upgradeable contract to a DAO.
    /// @param _dao The address of the updating DAO.
    /// @param _params The struct containing the parameters for the `applyInstallation` function.
    function applyUpdate(address _dao, ApplyUpdate calldata _params)
        external
        canApply(_dao, APPLY_UPDATE_PERMISSION_ID)
    {
        bytes32 pluginId = _getPluginId(_dao, _params.plugin);

        PluginInformation storage pluginInformation = states[pluginId];

        bytes32 setupId = _getSetupId(
            _params.pluginSetupRef,
            pHash(_params.permissions),
            _params.helpersHash,
            aHash(_params.actions),
            _params.initData
        );

        // If the plugin block number exceeds the setupId preparation block number,
        // This means applyUpdate was already called on another setupId
        // and all the rest setupIds should become idle or setupId is not prepared before.
        if (pluginInformation.blockNumber >= pluginInformation.setupIds[setupId]) {
            revert SetupNotEligible(setupId);
        }

        // Once the applyUpdate is called and arguments are confirmed(including initData)
        // we update the setupId with the new versionTag, the current helpers. All other
        // data can be put with bytes(0) as they don't need to be confirmed in the later 
        // prepareUpdate/prepareUninstallation.
        bytes32 newSetupId = _getSetupId(
            _params.pluginSetupRef,
            bytes32(0),
            _params.helpersHash,
            bytes32(0),
            bytes("")
        );

        pluginInformation.blockNumber = block.number;
        pluginInformation.currentSetupId = newSetupId;

        PluginRepo.Version memory version = _params.pluginSetupRef.pluginSetupRepo.getVersion(
            _params.pluginSetupRef.versionTag
        );

        address currentImplementation = PluginUUPSUpgradeable(_params.plugin)
            .getImplementationAddress();
        address newImplementation = PluginSetup(version.pluginSetup).getImplementationAddress();

        if (currentImplementation != newImplementation) {
            _upgradeProxy(_params.plugin, newImplementation, _params.initData);
        }

        _executeOnDAO(_dao, setupId, _params.permissions, _params.actions);
    }

    /// @notice Prepares the uninstallation of a plugin.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `prepareUninstallation` function.
    /// @return permissions The list of multi-targeted permission operations to be applied to the uninstalling DAO.
    /// @dev The list of `_currentHelpers` has to be specified in the same order as they were returned from previous setups preparation steps (the latest `prepareInstallation` or `prepareUpdate` step that has happend) on which the uninstallation was prepared for
    function prepareUninstallation(address _dao, PrepareUninstall calldata _params)
        external
        returns (PermissionLib.ItemMultiTarget[] memory permissions)
    {
        bytes32 pluginId = _getPluginId(_dao, _params.setupPayload.plugin);

        PluginInformation storage pluginInformation = states[pluginId];

        bytes32 setupId = _getSetupId(
            _params.pluginSetupRef,
            bytes32(0),
            hHash(_params.setupPayload.currentHelpers),
            bytes32(0),
            bytes("")
        );

        if (pluginInformation.currentSetupId != setupId) {
            revert InvalidSetupId({
                currentSetupId: pluginInformation.currentSetupId,
                setupId: setupId
            });
        }

        PluginRepo.Version memory version = _params.pluginSetupRef.pluginSetupRepo.getVersion(
            _params.pluginSetupRef.versionTag
        );

        permissions = PluginSetup(version.pluginSetup).prepareUninstallation(
            _dao,
            _params.setupPayload
        );

        bytes32 newSetupId = _getSetupId(
            _params.pluginSetupRef,
            pHash(permissions),
            bytes32(0),
            bytes32(0),
            bytes("")
        );

        // Only allow to prepare if setupId has not been prepared before.
        // Note that the following check ensures that the same setupId can be prepared
        // once again if the plugin was uninstalled and then installed/updated.. 
        if(pluginInformation.blockNumber < pluginInformation.setupIds[newSetupId]) {
            revert SetupAlreadyPrepared(setupId);
        }

        pluginInformation.setupIds[newSetupId] = block.number;
    }

    /// @notice Applies the permissions of a prepared uninstallation to a DAO.
    /// @param _dao The address of the DAO.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `applyUninstallation` function.
    /// @dev The list of `_currentHelpers` has to be specified in the same order as they were returned from previous setups preparation steps (the latest `prepareInstallation` or `prepareUpdate` step that has happend) on which the uninstallation was prepared for.
    function applyUninstallation(address _dao, ApplyUninstall calldata _params)
        external
        canApply(_dao, APPLY_UNINSTALLATION_PERMISSION_ID)
    {
        bytes32 pluginId = _getPluginId(_dao, _params.plugin);

        PluginInformation storage pluginInformation = states[pluginId];

        bytes32 setupId = _getSetupId(
            _params.pluginSetupRef,
            pHash(_params.permissions),
            _params.helpersHash,
            bytes32(0),
            bytes("")
        );

        // If the plugin block number exceeds the setupId preparation block number,
        // This means applyUninstallation was already called on another setupId
        // and all the rest setupIds should become idle or setupId is not prepared before.
        if (pluginInformation.blockNumber >= pluginInformation.setupIds[setupId]) {
            revert SetupNotEligible(setupId);
        }

        pluginInformation.blockNumber = block.number;
        pluginInformation.currentSetupId = bytes32(0);

        DAO(payable(_dao)).bulkOnMultiTarget(_params.permissions);
    }

    /// @notice Upgrades an UUPSUpgradeable proxy contract (see [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822)).
    /// @param _proxy The address of the UUPSUpgradeable proxy.
    /// @param _implementation The address of the implementation contract.
    /// @param _initData The initialization data to be passed to the upgradeable plugin contract via `upgradeToAndCall`.
    function _upgradeProxy(
        address _proxy,
        address _implementation,
        bytes memory _initData
    ) private {
        if (_initData.length > 0) {
            try
                PluginUUPSUpgradeable(_proxy).upgradeToAndCall(_implementation, _initData)
            {} catch Error(string memory reason) {
                revert(reason);
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                revert PluginProxyUpgradeFailed({
                    proxy: _proxy,
                    implementation: _implementation,
                    initData: _initData
                });
            }
        } else {
            try PluginUUPSUpgradeable(_proxy).upgradeTo(_implementation) {} catch Error(
                string memory reason
            ) {
                revert(reason);
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                revert PluginProxyUpgradeFailed({
                    proxy: _proxy,
                    implementation: _implementation,
                    initData: _initData
                });
            }
        }
    }

    /// @notice Internal function to check if a caller has the permission to apply a prepared setup.
    /// @param _dao The address of the DAO conducting the setup.
    /// @param _permissionId The permission identifier.
    function _canApply(address _dao, bytes32 _permissionId) private view {
        if (
            msg.sender != _dao &&
            !DAO(payable(_dao)).hasPermission(address(this), msg.sender, _permissionId, bytes(""))
        ) {
            revert SetupApplicationUnauthorized({
                dao: _dao,
                caller: msg.sender,
                permissionId: _permissionId
            });
        }
    }

    /// @notice Helper function to apply permissions + execute actions on the dao.
    /// @param _dao The address of the DAO conducting the setup.
    /// @param _setupId the setup id of the preparation object.
    /// @param _permissions The permissions array
    /// @param _actions The follow up actions that will be executed at the time of plugin installation/update.
    function _executeOnDAO(
        address _dao,
        bytes32 _setupId,
        PermissionLib.ItemMultiTarget[] calldata _permissions,
        IDAO.Action[] calldata _actions
    ) private {
        DAO dao = DAO(payable(_dao));

        // Process the permissions
        dao.bulkOnMultiTarget(_permissions);

        // Process the actions
        dao.grant(_dao, address(this), dao.EXECUTE_PERMISSION_ID());
        dao.execute(uint256(_setupId), _actions);
        dao.revoke(_dao, address(this), dao.EXECUTE_PERMISSION_ID());
    }
}
