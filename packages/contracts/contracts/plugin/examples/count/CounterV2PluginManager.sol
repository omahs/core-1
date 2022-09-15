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
        multiplyHelperBase = _helper;
        counterBase = new CounterV2();
    }

    function install(address dao, bytes memory data) external virtual override {
        // This changes as in V2, initialize now expects 3 arguments..
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num, uint256 _newVariable) = abi.decode(
            data,
            (address, uint256, uint256)
        );

        CounterV1 counter = createProxy(dao, address(counterBase), "0x");

        if (_multiplyHelper == address(0)) {
            // Deploy some internal helper contract for the Plugin
            _multiplyHelper = createProxy(dao, address(multiplyHelperBase), "0x");
        }

        counter.initialize(_multiplyHelper, _num);

        // Encode the parameters that will be passed to initialize() on the Plugin
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("function initialize(address,uint256))")),
            _multiplyHelper,
            _num
        );

        // Address of the helper so that PluginInstaller can grant the requested permissionOperations on it
        relatedContracts[0] = _multiplyHelper;

        // Deploy the Plugin itself, make it point to the implementation and
        // pass it the initialization params
        plugin = createProxy(dao, getImplementationAddress(), initData);

        BulkPermissionsLib.ItemMultiTarget[] permissionOperations = new BulkPermissionsLib.ItemMultiTarget[](
                3
            );

        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkBulkPermissionsLib.ItemMultiTargetsLib.Operation.Grant,
            where: dao,
            who: plugin,
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkBulkPermissionsLib.ItemMultiTargetsLib.Operation.Grant,
            where: plugin,
            who: dao,
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        permissionOperations[2] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkBulkPermissionsLib.ItemMultiTargetsLib.Operation.Grant,
            where: _multiplyHelper,
            who: plugin,
            oracle: NO_ORACLE,
            permissionId: _multiplyHelper.MULTIPLY_PERMISSION_ID()
        });

        aragonPluginInstaller.storePermissionOperations(dao, permissionOperations);
    }

    function update(
        address proxy,
        uint16[3] calldata oldVersion,
        bytes memory data
    ) external virtual override {
        uint256 _newVariable;

        // TODO: improve the example to handle more complicated scenario...
        if (oldVersion[0] == 1) {
            (_newVariable) = abi.decode(data, (uint256));
        }

        // TODO: Shall we leave it here or make devs call `upgrade` from our abstract factory
        // Just a way of reinforcing...
        // TODO1: proxy needs casting to UUPSSUpgradable
        // TODO2: 2nd line needs casting to CounterV2
        // proxy.upgradeTo(getImplementationAddress());
        CounterV2(proxy).setNewVariable(_newVariable);

        address whoCanCallMultiply = abi.decode(data, (address));

        permissionOperations = new RequestedBulkPermissionsLib.ItemMultiTarget[](2);

        // Now, revoke permission so dao can't call anymore this multiply function on plugin.
        permissionOperations[0] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkBulkPermissionsLib.ItemMultiTargetsLib.Operation.revoke,
            where: plugin,
            who: dao,
            oracle: NO_ORACLE,
            permissionId: counterBase.MULTIPLY_PERMISSION_ID()
        });

        // ALLOW Some 3rd party to be able to call multiply on plugin after update.
        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkBulkPermissionsLib.ItemMultiTargetsLib.Operation.Grant,
            where: plugin,
            who: whoCanCallMultiply,
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
            op: BulkPermissionsLib.Operation.Grant,
            where: dao,
            who: counter,
            oracle: NO_ORACLE,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissionOperations[1] = BulkPermissionsLib.ItemMultiTarget({
            op: BulkPermissionsLib.Operation.Grant,
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
