// SPDX-License-Identifier:    MIT
 
pragma solidity 0.8.10;

import "../utils/PluginERC1967Proxy.sol";
import "../core/permission/BulkPermissionsLib.sol";
import "./PluginConstants.sol";

/// @notice A library to share the interface ID of the abstract `PluginFactoryBase` contract.
library PluginFactoryIDs {
    /// @notice The interface ID of the `PluginFactoryBase` contract.
    bytes4 public constant PLUGIN_FACTORY_INTERFACE_ID = type(PluginManager).interfaceId;
}

/// @notice Abstract Plugin Factory that dev's have to inherit from for their factories.
abstract contract PluginManager is PluginConstants {
    
    struct Permission {
        BulkPermissionsLib.Operation op;
        uint where; // index from relatedContracts or the actual address
        bool isWhereAddres; // whether or not `where` is index from relatedContracts or address directly.
        uint who; // index from relatedContracts or the actual address
        bool isWhoAddress; // whether or not `who` is index from relatedContracts or address directly.
        address oracle;
        bytes32 role;
    }
    
    /// @notice creates Permission struct
    /// @param op Whether grants, revokes, freezes...
    /// @param where index from the dev's deployed addresses array where permission will be set.
    /// @param who index from the dev's deployed addresses array
    /// @param role role that will be set
    /// @return Permission The final permission struct
    function createPermission(
        BulkPermissionsLib.Operation op, 
        uint256 where, 
        uint256 who,
        address oracle,
        bytes32 role
    ) internal pure returns (Permission memory) {
        return Permission(op, where, false, who, false, oracle, role);
    }

    /// @notice creates Permission struct
    /// @param op Whether grants, revokes, freezes...
    /// @param where Address where permission will be granted.
    /// @param who Address who will have the permission.
    /// @param role role that will be set
    /// @return Permission The final permission struct
    function createPermission(
        BulkPermissionsLib.Operation op, 
        address where, 
        address who,
        address oracle, 
        bytes32 role
    ) internal pure returns (Permission memory) {
        return Permission(op, uint(uint160(where)), true, uint(uint160(who)), true, oracle, role);
    }

    /// @notice creates Permission struct
    /// @param op Whether grants, revokes, freezes...
    /// @param where index from the dev's deployed addresses array where permission will be set.
    /// @param who Address who will have the permission.
    /// @param role role that will be set
    /// @return Permission The final permission struct
    function createPermission(
        BulkPermissionsLib.Operation op, 
        uint256 where, 
        address who,
        address oracle,
        bytes32 role
    ) internal pure returns (Permission memory) {
        return Permission(op, where, false, uint(uint160(who)), true, oracle, role);
    }

    /// @notice creates Permission struct
    /// @param op Whether grants, revokes, freezes...
    /// @param where Address who will have the permission.
    /// @param who index from the dev's deployed addresses array that will have permission.
    /// @param role role that will be set
    /// @return Permission The final permission struct
    function createPermission(
        BulkPermissionsLib.Operation op, 
        address where, 
        uint256 who,
        address oracle,
        bytes32 role
    ) internal pure returns (Permission memory) {
        return Permission(op, uint(uint160(where)), true, who, false, oracle, role);
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param dao dao address
    /// @param logic the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    /// @return address of the proxy.
    function createProxy(address dao, address logic, bytes memory init) internal returns(address) {
        return address(new PluginERC1967Proxy(dao, logic, init));
    }

    /// @notice helper function to deploy Custom ERC1967Proxy that includes dao slot on it.
    /// @param proxy proxy address
    /// @param logic the base contract address proxy has to delegate calls to.
    /// @param init the initialization data(function selector + encoded data)
    function upgrade(address proxy, address logic, bytes memory init) internal {
        // TODO: shall we implement this ?    
    }

    /// @notice the function dev has to override/implement for the plugin deployment.
    /// @param dao dao address where plugin will be installed to in the end.
    /// @param data the ABI encoded data that deploy needs for its work.
    /// @return plugin the plugin address
    /// @return relatedContracts array of helper contract addresses that dev deploys beforehand the plugin.
    function deploy(
        address dao, 
        bytes memory data
    ) external virtual returns(address plugin, address[] memory relatedContracts);
    
    /// @notice the function dev has to override/implement for the plugin update.
    /// @param proxy proxy address
    /// @param oldVersion the version plugin is updating from.
    /// @param data the other data that deploy needs.
    /// @return relatedContracts array of helper contract addresses that dev deploys to do some work before plugin update.
    function update(
        address proxy,
        uint16[3] calldata oldVersion, 
        bytes memory data
    ) external virtual returns(address[] memory relatedContracts) {}

    /// @notice the plugin's base implementation address proxies need to delegate calls.
    /// @return address of the base contract address.
    function getImplementationAddress() public virtual view returns(address);

    /// @notice the ABI in string format that deploy function needs to use.
    /// @return ABI in string format.
    function deployABI() external virtual view returns (string memory);

    /// @notice The ABI in string format that update function needs to use.
    /// @dev Not required to be overriden as there might be no update at all by dev.
    /// @return ABI in string format.
    function updateABI() external virtual view returns (string memory) {}

    /// @notice the view function called by UI to detect the permissions that will be applied before installing the plugin.
    /// @dev This corresponds to the permissions for installing the plugin.
    /// @param data the exact same data that is passed to the deploy function.
    /// @return Permissions the permission struct array that contain all the permissions that should be set.
    /// @return array of strings(names of helper contracts). This corresponds to the relatedContracts.
    function getInstallPermissions(bytes memory data) external view virtual returns(Permission[] memory, string[] memory);

    /// @notice the view function called by UI to detect the permissions that will be applied before updating the plugin.
    /// @dev This corresponds to the permissions for updating the plugin.
    /// @param oldVersion the version plugin is updating from.
    /// @param data the exact same data that is passed to the update function.
    /// @return Permissions the permissions struct array that contain all the permissions that should be set.
    /// @return array of strings(names of helper contracts). This corresponds to the relatedContracts.
    function getUpdatePermissions(
        uint16[3] calldata oldVersion, 
        bytes memory data
    ) external virtual returns(Permission[] memory, string[] memory) {}
}