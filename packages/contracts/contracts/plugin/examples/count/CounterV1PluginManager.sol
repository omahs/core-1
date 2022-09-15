// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../PluginManager.sol";
import "./MultiplyHelper.sol";
import "./CounterV1.sol";

contract CounterV1PluginManager is PluginManager {
    MultiplyHelper private multiplyHelperBase;
    CounterV1 private counterBase;

    address private constant NO_ORACLE = address(0);

    constructor() {
        associatedContractsCount = 3;
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(counterBase);
    }

    function getMultiplyHelperAddress(uint256 _nonce) internal view returns (address) {
        return associatedContracts[nonce][2];
    }

    function install(address dao, bytes memory data) external virtual override {
        ++nonce;

        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(data, (address, uint256));

        // Deploy the plugin
        address counter = createProxy(dao, address(counterBase), "0x");

        if (_multiplyHelper == address(0)) {
            // Deploy some internal helper contract for the Plugin
            _multiplyHelper = createProxy(dao, address(multiplyHelperBase), "0x");
        }

        associatedContracts[nonce] = new address[](3);
        associatedContracts[nonce][0] = dao;
        associatedContracts[nonce][1] = counter;
        associatedContracts[nonce][2] = _multiplyHelper;

        CounterV1(counter).initialize(MultiplyHelper(_multiplyHelper), _num); // what if a permission is needed?
    }

    function getInstallPermissionOps(uint256 _nonce)
        external
        override
        assertAssociatedContractCount(_nonce)
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getPluginAddress(_nonce),
            who: getPluginAddress(_nonce),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });
        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getDaoAddress(_nonce),
            who: getPluginAddress(_nonce),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUninstallPermissionOps(uint256 _nonce)
        external
        view
        override
        assertAssociatedContractCount(_nonce)
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getDaoAddress(_nonce),
            who: getPluginAddress(_nonce),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Revoke,
            where: getDaoAddress(_nonce),
            who: getPluginAddress(_nonce),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }
}
