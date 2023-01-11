// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {PermissionLib} from "../../../core/permission/PermissionLib.sol";
import {IDAO} from "../../../core/IDAO.sol";
import {PluginSetup} from "../../../plugin/PluginSetup.sol";
import {IPluginSetup} from "../../../plugin/IPluginSetup.sol";
import {PluginCloneableV1Mock, PluginCloneableV2Mock} from "./PluginCloneableMock.sol";
import {mockPermissions, mockHelpers, mockPluginProxy} from "../PluginMockData.sol";

contract PluginCloneableSetupV1Mock is PluginSetup {
    address internal pluginBase;

    constructor() {
        pluginBase = address(new PluginCloneableV1Mock());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallationDataABI() external view virtual override returns (string memory) {
        return "";
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes memory)
        public
        virtual
        override
        returns (address plugin, PreparedDependency memory preparedDependency)
    {
        plugin = mockPluginProxy(pluginBase, _dao);
        preparedDependency.helpers = mockHelpers(1);
        preparedDependency.permissions = mockPermissions(5, 6, PermissionLib.Operation.Grant);
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallationDataABI() external view virtual override returns (string memory) {
        return "";
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        virtual
        override
        returns (PermissionLib.ItemMultiTarget[] memory permissions)
    {
        (_dao, _payload);
        permissions = mockPermissions(5, 6, PermissionLib.Operation.Revoke);
    }

    /// @inheritdoc IPluginSetup
    function getImplementationAddress() external view virtual override returns (address) {
        return address(pluginBase);
    }
}

contract PluginCloneableSetupV2Mock is PluginCloneableSetupV1Mock {
    constructor() {
        pluginBase = address(new PluginCloneableV2Mock());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallationDataABI() external view virtual override returns (string memory) {
        return "";
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes memory)
        public
        virtual
        override
        returns (address plugin, PreparedDependency memory preparedDependency)
    {
        plugin = mockPluginProxy(pluginBase, _dao);
        preparedDependency.helpers = mockHelpers(1);
        preparedDependency.permissions = mockPermissions(5, 7, PermissionLib.Operation.Grant);
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallationDataABI() external view virtual override returns (string memory) {
        return "";
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        virtual
        override
        returns (PermissionLib.ItemMultiTarget[] memory permissions)
    {
        (_dao, _payload);
        permissions = mockPermissions(5, 7, PermissionLib.Operation.Revoke);
    }

    /// @inheritdoc IPluginSetup
    function getImplementationAddress() external view virtual override returns (address) {
        return address(pluginBase);
    }
}
