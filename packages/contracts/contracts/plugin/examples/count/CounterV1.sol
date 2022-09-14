// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {PluginUUPSUpgradeable} from "../../../core/plugin/PluginUUPSUpgradeable.sol";
import {PluginInstaller} from "../../../plugin/PluginInstaller.sol";
import {MultiplyHelper} from "./MultiplyHelper.sol";
import {IDAO} from "../../../core/IDAO.sol";

/// @notice The first version of example plugin - CounterV1.
contract CounterV1 is PluginUUPSUpgradeable {
    bytes32 public constant MULTIPLY_PERMISSION_ID = keccak256("MULTIPLY_PERMISSION");

    struct PluginInstallRequest {
        bytes32 pluginId;
        bytes memory data;
    }
    struct Proposal {
        bytes32 proposalId;
        bool executed;
        bool isPlugin;
        uint256 deploymentId;
    }

    uint256 public count;
    MultiplyHelper public multiplyHelper;

    function initialize(MultiplyHelper _multiplyHelper, uint256 _num) external initializer {
        count = _num;
        multiplyHelper = _multiplyHelper;
    }

    function multiply(uint256 a) public auth(MULTIPLY_PERMISSION_ID) returns (uint256) {
        count = multiplyHelper.multiply(count, a);
        return count;
    }

    function createProposal(string _metadataEtc, IDAO.Action[] memory actions) {}

    function createPluginProposal(
        string _metadataEtc,
        address daoAddress,
        address pluginInstaller,
        PluginInstallRequest pluginInfo
    ) {
        // Resolve pluginInfo.pluginId => version => PluginManager
        
        uint256 deploymentId = PluginInstaller(pluginInstaller).addDeployment(daoAddress, plugin);

        // Store proposal ID => deploymentID
    }

    function createUpgradeProposal(string _metadata, uint16[3] calldata newVersion) {
        // We can know the PluginID

        // TODO: UNRESOLVED
        // TODO: We don't use the PluginManager, so the dev has to do everything manually
        // TODO: We don't know how our new version will look like
    }

    function execute(bytes32 proposalId) public {
        // if not passed: revert()

        // IF PROPOSAL IS STANDARD:
        // IDAO dao = dao();
        // dao.execute(...)

        // IF PSOPOSAL IS PLUGIN:
        // pluginInstaller.commitDeployment(cid);
    }

    // Lifecycle

    // Called by proposal.execute() => DAO.execute() => this.onUpdate()
    function onUpdate(
        address proxy,
        uint16[3] calldata oldVersion,
        bytes memory data
    ) public returns (bytes memory newInitData) {
        // Detect what needs handling from old > new version
    }
}
