// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../utils/PluginERC1967Proxy.sol";
import "../core/permission/BulkPermissionsLib.sol";
import {DAO} from "../core/DAO.sol";

/// NOTE: This is an untested code and should NOT be used in production.
/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManager {
    bytes4 public constant PLUGIN_MANAGER_INTERFACE_ID = type(PluginManager).interfaceId;

    uint256 public nonce;
    uint256 public associatedContractsCount;

    mapping(uint256 => address[]) associatedContracts; // the array length can vary across plugin version

    error InvalidLength(uint256 expected, uint256 actual);

    modifier assertAssociatedContractCount(uint256 _nonce) {
        if (associatedContractsCount != associatedContracts[_nonce].length) {
            revert InvalidLength(associatedContractsCount, associatedContracts[_nonce].length);
        }
        _;
    }

    function incrementNonce() internal {
        nonce++;
    }

    function getDaoAddress(uint256 _nonce) public view returns (address) {
        return associatedContracts[_nonce][0];
    }

    function getPluginAddress(uint256 _nonce) public view returns (address) {
        return associatedContracts[_nonce][1];
    }

    function getImplementationAddress() public view virtual returns (address);

    function install(address _dao, bytes memory _data) external returns (uint256 deploymentNonce) {
        incrementNonce();
        _install(_dao, _data);
        return nonce;
    }

    function update(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        bytes memory _data
    ) external returns (uint256 deploymentNonce) {
        incrementNonce();
        _update(_oldPluginManager, _oldNonce, _data);
        return nonce;
    }

    function _install(address _dao, bytes memory _data) internal virtual;

    function _update(
        PluginManager _oldPluginManager,
        uint256 _oldNonce,
        bytes memory _data
    ) internal virtual {}

    // No deployment takes place here - so no need to return a nonce
    function uninstall(bytes memory data) internal virtual {}

    function getInstallPermissionOps(uint256 _nonce)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function getUpdatePermissionOps(uint256 _nonce)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory)
    {}

    function getUninstallPermissionOps(uint256 _nonce)
        external
        view
        virtual
        returns (BulkPermissionsLib.ItemMultiTarget[] memory);

    function postInstallHook(uint256 _nonce) external virtual {}

    function postUpdateHook(uint256 _nonce) external virtual {}

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
