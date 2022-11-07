// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ENSSubdomainRegistrar} from "./ens/ENSSubdomainRegistrar.sol";
import {IDAO} from "../core/IDAO.sol";
import {InterfaceBasedRegistry} from "./InterfaceBasedRegistry.sol";
import {IPluginRepo} from "../plugin/IPluginRepo.sol";

/// @title PluginRepoRegistry
/// @author Aragon Association - 2022
/// @notice This contract maintains an address-based registery of plugin repositories in the Aragon App DAO framework.
contract PluginRepoRegistry is InterfaceBasedRegistry {
    /// @notice The ID of the permission required to call the `register` function.
    bytes32 public constant REGISTER_PLUGIN_REPO_PERMISSION_ID =
        keccak256("REGISTER_PLUGIN_REPO_PERMISSION");

    /// @notice The ENS subdomain registrar registering the PluginRepo names.
    ENSSubdomainRegistrar public subdomainRegistrar;

    /// @notice The namehash of the domain on which subdomains are registered.
    bytes32 public node;

    /// @notice Emitted if a new plugin repository is registered.
    /// @param name The name of the plugin repository.
    /// @param pluginRepo The address of the plugin repository.
    event PluginRepoRegistered(string name, address pluginRepo);

    /// @notice Initializes the contract by setting calling the `InterfaceBasedRegistry` base class initialize method.
    /// @param _dao The address of the managing DAO.
    /// TODO: add missing natspecs
    function initialize(
        IDAO _dao,
        ENSSubdomainRegistrar _subdomainRegistrar,
        bytes32 _node
    ) public initializer {
        bytes4 pluginRepoInterfaceId = type(IPluginRepo).interfaceId;
        __InterfaceBasedRegistry_init(_dao, pluginRepoInterfaceId);

        subdomainRegistrar = _subdomainRegistrar;
        node = _node;
    }

    /// @notice Registers a plugin repository with a name and address.
    /// @param name The name of the PluginRepo.
    /// @param registrant The address of the PluginRepo contract.  // TODO: perhaps change the name of registrant to pluginRepo
    function registerPluginRepo(string calldata name, address registrant)
        external
        auth(REGISTER_PLUGIN_REPO_PERMISSION_ID)
    {
        // The caller(PluginRepoFactory) explicitly checks
        // if the name is empty and reverts.

        bytes32 labelhash = keccak256(bytes(name));
        subdomainRegistrar.registerSubnode(node, labelhash, registrant);

        _register(registrant);

        emit PluginRepoRegistered(name, registrant);
    }

    /// @notice This empty reserved space is put in place to allow future versions to add new variables without shifting down storage in the inheritance chain (see [OpenZepplins guide about storage gaps](https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps)).
    uint256[48] private __gap;
}
