// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Permission, PluginManager, PluginManagerLib} from "../../PluginManager.sol";
import {MultiplyHelper} from "./MultiplyHelper.sol";
import {CounterV1} from "./CounterV1.sol";

contract CounterV1PluginManager is PluginManager {
    using Clones for address;
    using PluginManagerLib for PluginManagerLib.Data;

    // For testing purposes, the below are public...
    MultiplyHelper public multiplyHelperBase;
    CounterV1 public counterBase;

    address private constant NO_ORACLE = address(0);
    address private constant DAO_ADDRESS = address(-1);
    bytes32 private constant EXECUTE_PERMISSION_ID = keccak256("EXECUTE_PERMISSION");

    constructor() {
        multiplyHelperBase = new MultiplyHelper();
        counterBase = new CounterV1();
    }

    function deploy(bytes memory data)
        public
        virtual
        returns (Permission.ItemMultiTarget[] permissions)
    {
        address multiplyAddress = createProxy(multiplyHelperBase, data);

        bytes memory pluginData = abi.encode(multiplyAddress, (address));
        address pluginAddress = createProxy(counterBase, pluginData);

        // TODO: Remove grant, assume always grant
        permissions.push(
            Permission.ItemMultiTarget(
                Permission.Operation.Grant,
                pluginAddress,
                multiplyAddress,
                NO_ORACLE,
                EXECUTE_PERMISSION_ID
            )
        );
        permissions.push(
            Permission.ItemMultiTarget(
                Permission.Operation.Grant,
                DAO_ADDRESS,
                pluginAddress,
                NO_ORACLE,
                EXECUTE_PERMISSION_ID
            )
        );
        return permissions;
    }

    /*
    function _getInstallInstruction(PluginManagerLib.Data memory installation)
        internal
        view
        override
        returns (PluginManagerLib.Data memory)
    {
        // Decode the parameters from the UI
        (address _multiplyHelper, uint256 _num) = abi.decode(
            installation.params,
            (address, uint256)
        );

        address multiplyHelper = _multiplyHelper;

        if (_multiplyHelper == address(0)) {
            multiplyHelper = installation.addHelper(address(multiplyHelperBase), bytes(""));
        }

        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,uint256)")),
            multiplyHelper,
            _num
        );

        // TODO 1: If dev wants his plugin to be deployed with `new`, with the current solution,
        // he is still obliged to deploy things as bases inside plugin manager constructor eve though
        // it's not required. + hence more gas costs

        // TODO 2: installation.addPlugin is the way to use everything correctly. Though, dev can
        // stil write installation.plugins = new PluginManagerLib.Deployment[](3) and then 
        // directly put some other addresses instead of plugin which mean create2 will produce a different addresses
        address pluginAddr = installation.addPlugin(address(counterBase), initData);

        installation.addPermission(
            Permission.Operation.Grant,
            installation.dao,
            pluginAddr,
            NO_ORACLE,
            keccak256("EXEC_PERMISSION")
        );

        installation.addPermission(
            Permission.Operation.Grant,
            pluginAddr,
            installation.dao,
            NO_ORACLE,
            counterBase.MULTIPLY_PERMISSION_ID()
        );

        if (_multiplyHelper == address(0)) {
            installation.addPermission(
                Permission.Operation.Grant,
                multiplyHelper,
                pluginAddr,
                NO_ORACLE,
                multiplyHelperBase.MULTIPLY_PERMISSION_ID()
            );
        }
        return installation;
    }
    */

    function getImplementationAddress() public view virtual override returns (address) {
        return address(counterBase);
    }

    function deployABI() external view virtual override returns (string memory) {
        return "(address multiplyHelper, uint num)";
    }
}
