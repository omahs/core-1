// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {PermissionLib} from "../../../core/permission/PermissionLib.sol";
import {IPluginSetup} from "../../../framework/plugin/setup/IPluginSetup.sol";
import {PluginSetup} from "../../../framework/plugin/setup/PluginSetup.sol";
import {MultiplyHelper} from "../MultiplyHelper.sol";
import {CounterV1} from "./CounterV1.sol";

/// @title CounterV1PluginSetup
/// @author Aragon Association - 2022-2023
/// @notice The setup contract of the `CounterV1` plugin.
contract CounterV1PluginSetup is PluginSetup {
    using Clones for address;

    // For testing purposes, the below are public...
    MultiplyHelper public multiplyHelperBase;
    CounterV1 public counterBase;

    address private constant NO_CONDITION = address(0);

    constructor() {
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes memory _data
    )
        external
        virtual
        override
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(_data, (address, uint256));

        address multiplyHelper = _multiplyHelper;

        if (_multiplyHelper == address(0)) {
            multiplyHelper = createERC1967Proxy(address(multiplyHelperBase), bytes(""));
        }

        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,address,uint256)")),
            _dao,
            multiplyHelper,
            _num
        );

        PermissionLib.MultiTargetPermission[]
            memory permissions = new PermissionLib.MultiTargetPermission[](
                _multiplyHelper == address(0) ? 3 : 2
            );
        address[] memory helpers = new address[](1);

        // deploy
        plugin = createERC1967Proxy(address(counterBase), initData);

        // set permissions
        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            _dao,
            plugin,
            NO_CONDITION,
            keccak256("EXECUTE_PERMISSION")
        );

        permissions[1] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            plugin,
            _dao,
            NO_CONDITION,
            counterBase.MULTIPLY_PERMISSION_ID()
        );

        if (_multiplyHelper == address(0)) {
            permissions[2] = PermissionLib.MultiTargetPermission(
                PermissionLib.Operation.Grant,
                multiplyHelper,
                plugin,
                NO_CONDITION,
                multiplyHelperBase.MULTIPLY_PERMISSION_ID()
            );
        }

        // add helpers
        helpers[0] = multiplyHelper;

        preparedSetupData.helpers = helpers;
        preparedSetupData.permissions = permissions;

        return (plugin, preparedSetupData);
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external virtual override returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        permissions = new PermissionLib.MultiTargetPermission[](
            _payload.currentHelpers.length != 0 ? 3 : 2
        );

        // set permissions
        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _dao,
            _payload.plugin,
            NO_CONDITION,
            keccak256("EXECUTE_PERMISSION")
        );

        permissions[1] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _payload.plugin,
            _dao,
            NO_CONDITION,
            counterBase.MULTIPLY_PERMISSION_ID()
        );

        if (_payload.currentHelpers.length != 0) {
            permissions[2] = PermissionLib.MultiTargetPermission(
                PermissionLib.Operation.Revoke,
                _payload.currentHelpers[0],
                _payload.plugin,
                NO_CONDITION,
                multiplyHelperBase.MULTIPLY_PERMISSION_ID()
            );
        }
    }

    /// @inheritdoc IPluginSetup
    function getImplementationAddress() external view virtual override returns (address) {
        return address(counterBase);
    }
}
