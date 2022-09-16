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

    function getMultiplyCallerAddress(uint256 _deploymentId) internal view returns (address) {
        return helpers[_deploymentId][2];
    }

    function _install(address dao, bytes memory data)
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

        addRelatedHelper(deploymentId, _multiplyHelper);
    }

    function _update(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        bytes memory data
    ) internal virtual override {
        //TODO check that `oldPluginManager` is in the same `PluginRepo` and that the version is lower
        // require(...);

        //decode data
        address whoCanCallMultiply = abi.decode(data, (address));

        addRelatedHelper(deploymentId, whoCanCallMultiply);
    }

    function getInstallPermissionOps(uint256 _deploymentId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](3);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getDaoAddress(_deploymentId),
            who: getPluginAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_deploymentId),
            who: getDaoAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        permissionOperations[2] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_deploymentId), // multiplyHelper
            who: getMultiplyCallerAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUpdatePermissionOps(uint256 _deploymentId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getPluginAddress(_deploymentId),
            who: getDaoAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_deploymentId),
            who: getMultiplyCallerAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUninstallPermissionOps(uint256 _deploymentId)
        external
        view
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getDaoAddress(_deploymentId),
            who: getPluginAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getPluginAddress(_deploymentId),
            who: getMultiplyCallerAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }
}
