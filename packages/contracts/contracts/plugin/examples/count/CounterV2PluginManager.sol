// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../PluginManager.sol";
import "./MultiplyHelper.sol";
import "./CounterV2.sol";

contract CounterV2PluginManager is PluginManager {
    MultiplyHelper private multiplyHelperBase;
    CounterV2 private counterBase;

    address private constant NO_ORACLE = address(0);

    // MultiplyHelper doesn't change. so dev decides to pass the old one.
    constructor(MultiplyHelper _helper) {
        helpersCount = 3;

        multiplyHelperBase = _helper;
        counterBase = new CounterV2();
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(counterBase);
    }

    function getMultiplyCallerAddress(uint256 _setupId) internal view returns (address) {
        return helpers[_setupId][2];
    }

    function _prepareInstall(address dao, bytes memory data)
        internal
        virtual
        override
        returns (address plugin)
    {
        // This changes as in V2, initialize now expects 3 arguments..
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num, uint256 _newVariable) = abi.decode(
            data,
            (address, uint256, uint256)
        );

        if (_multiplyHelper == address(0)) {
            // Deploy some internal helper contract for the Plugin
            _multiplyHelper = createProxy(dao, address(multiplyHelperBase), "0x");
        }

        plugin = createProxy(dao, getImplementationAddress(), "0x");

        CounterV2(plugin).initialize(MultiplyHelper(_multiplyHelper), _num, _newVariable);

        addRelatedHelper(setupId, _multiplyHelper);
    }

    function _prepareUpdateWithUpgrade(
        PluginManager _oldPluginManager,
        uint256 _oldSetupId,
        bytes memory data
    ) internal virtual override returns (bytes memory initData) {
        //decode data
        address whoCanCallMultiply = abi.decode(data, (address));

        addRelatedHelper(setupId, whoCanCallMultiply);

        // optionally, access old `_oldPluginManager` state of the old deployments

        // prepare init data
        initData = abi.encode(123);
    }

    function getInstallPermissionOps(uint256 _setupId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](3);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getDaoAddress(_setupId),
            who: getPluginAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_setupId),
            who: getDaoAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        permissionOperations[2] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_setupId), // multiplyHelper
            who: getMultiplyCallerAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUpdatePermissionOps(uint256 _setupId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getPluginAddress(_setupId),
            who: getDaoAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_setupId),
            who: getMultiplyCallerAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUninstallPermissionOps(uint256 _setupId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getDaoAddress(_setupId),
            who: getPluginAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getPluginAddress(_setupId),
            who: getMultiplyCallerAddress(_setupId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }
}
