// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../PluginManager.sol";
import "../../PluginInstaller.sol";
import "./MultiplyHelper.sol";
import "./CounterV1.sol";

contract CounterV1PluginManager is PluginManager {
    MultiplyHelper private multiplyHelperBase;
    CounterV1 private counterBase;

    address private constant NO_ORACLE = address(0);

    address[] deployedContracts;

    constructor() {
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    function install(address dao, bytes memory data)
        external
        virtual
        override
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(data, (address, uint256));

        // Deploy the plugin
        address counter = createProxy(dao, address(counterBase), "0x");

        if (_multiplyHelper == address(0)) {
            // Deploy some internal helper contract for the Plugin
            _multiplyHelper = createProxy(dao, address(multiplyHelperBase), "0x");
        }

        counter.initialize(_multiplyHelper, _num); // what if a permission is needed?

        BulkPermissionsLib.ItemMultiTarget[] permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](
                2
            );

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkPermissionsLib.Operation.Grant,
            where: dao,
            who: counter,
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkPermissionsLib.Operation.Grant,
            where: dao,
            who: counter,
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        aragonPluginInstaller.storePermissionOperations(dao, permissionOperations);
    }

    function uninstall(address dao, bytes memory data) external virtual override {
        BulkPermissionsLib.ItemMultiTarget[] permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](
                2
            );

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkPermissionsLib.Operation.revoke,
            where: dao,
            who: counter,
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkPermissionsLib.Operation.revoke,
            where: counter,
            who: dao,
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        aragonPluginInstaller.storePermissionOperations(dao, permissionOperations);
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(counterBase);
    }
}
