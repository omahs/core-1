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
        helpersCount = 3;
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    function getImplementationAddress() public view virtual override returns (address) {
        return address(counterBase);
    }

    function _install(address dao, bytes memory data)
        internal
        virtual
        override
        returns (address plugin)
    {
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(data, (address, uint256));

        // Deploy the plugin
        plugin = createProxy(dao, address(counterBase), "0x");

        if (_multiplyHelper == address(0)) {
            // Deploy some internal helper contract for the Plugin
            _multiplyHelper = createProxy(dao, address(multiplyHelperBase), "0x");
        }

        addRelatedHelper(deploymentId, _multiplyHelper);

        CounterV1(plugin).initialize(MultiplyHelper(_multiplyHelper), _num);

        // increment for the next deployment
        ++deploymentId;
    }

    function getInstallPermissionOps(uint256 _deploymentId)
        external
        view
        override
        assertAssociatedContractCount(_deploymentId)
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissionOperations)
    {
        permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](2);

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getDaoAddress(_deploymentId),
            who: getPluginAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });
        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            operation: BulkPermissionsLib.Operation.Grant,
            where: getDaoAddress(_deploymentId),
            who: getPluginAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }

    function getUninstallPermissionOps(uint256 _deploymentId)
        external
        view
        override
        assertAssociatedContractCount(_deploymentId)
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
            where: getDaoAddress(_deploymentId),
            who: getPluginAddress(_deploymentId),
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });
    }
}
