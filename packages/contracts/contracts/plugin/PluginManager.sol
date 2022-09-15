// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./PluginInstaller.sol";
import "../utils/PluginERC1967Proxy.sol";
import "../core/permission/BulkPermissionsLib.sol";

/// NOTE: This is an untested code and should NOT be used in production.
/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManager {
    bytes4 public constant PLUGIN_MANAGER_INTERFACE_ID = type(PluginManager).interfaceId;

    PluginInstaller internal constant aragonPluginInstaller = PluginInstaller(address(0x123)); // replace with real address

    function getImplementationAddress() public view virtual returns (address);

    function install(address dao, bytes memory data)
        external
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissions);

    function postInstallHook() external virtual {}

    function update(
        address proxy,
        uint16[3] calldata oldVersion,
        bytes memory data
    ) external virtual returns (BulkPermissionsLib.ItemMultiTarget[] memory permissions);

    function postUpdateHook() external virtual {}

    function uninstall(address proxy, bytes memory data)
        external
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory permissions);

    function postUninstallHook() external virtual {}

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param dao dao address
    /// @param logic the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    /// @return address of the proxy.
    function createProxy(
        address dao,
        address logic,
        bytes memory init
    ) internal returns (address) {
        return address(new PluginERC1967Proxy(dao, logic, init));
    }
}
