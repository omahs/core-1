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
        uint8[3] memory version;
        bytes memory data;
    }
    struct Proposal {
        uint256 proposalId;
        bool executed;
        bool isPlugin;
        bytes32 deploymentId;
        IDAO.Action[] actions;
    }

    uint256 public proposalCount = 0;
    mapping(uint256 => Proposal) public proposals;

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

    function createProposal(string _metadataEtc, IDAO.Action[] memory actions) {
        // Store proposal ID => deploymentID
        proposals[proposalCount].push(Proposal(proposalCount, false, false, deploymentId, actions));
        proposalCount++;

        // emit event
    }

    function createPluginProposal(
        string _metadataEtc,
        address daoAddress,
        address pluginInstaller,
        PluginInstallRequest pluginInfo
    ) {
        // Encode plugin deployment request
        bytes32 memory initData = abi.encode(0x1234, (bytes2));

        PluginInstallParams installParams = PluginManagementLib.wrapPluginInstallParams(pluginInfo.pluginId, pluginInfo.version, initData);
        bytes32 deploymentId = pluginInstaller.createDeployment(daoAddress, installParams);

        // Store proposal ID => deploymentID
        Proposal newProposal = Proposal(proposalCount, false, true, deploymentId, []);
        proposals[proposalCount].push(newProposal);
        proposalCount++;

        // Emit event?
    }

    function createUpdateProposal(
        string _metadata,
        uint16[3] calldata newVersion,
        bytes memory updateInitData,
        address pluginInstaller
    ) {
        // TODO: We need to know our own Plugin ID (within the plugin registry)

        // TODO: Resolve our newer plugin manager address from the registry
        address newPluginManagerAddr = PluginRegistry.resolve(pluginId, newVersion);

        PluginUpdateParams updateDetails = PluginUpdateParams(
            newPluginManagerAddr,
            updateInitData, // post update params
            address(this), // the proxy
            [1, 2, 1] // our own version (old)
        );

        // Execute
        IDAO.Action[] installActionList = [
            // abi.encodeWithSelector( ___ pluginInstaller.updatePlugin(updateDetails) ___ );
        ];
        // TODO: callID/proposalID needs to be unique => salted+hashed
        this.dao().execute(proposalId, installActionList);
    }

    function execute(uint256 proposalId) public {
        // if not passed: revert()

        if (proposalId >= proposals.length) revert("");
        else if (proposals[proposalId].executed) revert("");
        else if (!proposals[proposalId].isPlugin) {
            // TODO: callID/proposalID needs to be unique => salted+hashed
            this.dao().execute(proposalId, proposals[proposalId].actions);
        } else {
            // Plugin update proposal

            IDAO.Action[] installActionList = [
                // abi.encodeWithSelector( ___ pluginInstaller.commitDeployment(cid) ___ );
            ];
            // TODO: callID/proposalID needs to be unique => salted+hashed
            this.dao().execute(proposalId, installActionList);
        }

        proposals[proposalId].executed = true;
    }

    // Lifecycle

    // Called by proposal.execute() => DAO.execute() => this.onUpdate()
    function onUpdate(uint16[3] calldata oldVersion, bytes memory data)
        public
        returns (bytes memory newInitData)
    {
        // Detect what needs handling from old > new version
        if(oldVersion[0] == 1 && oldVersion[1] <= 1) {
            // do something
        }
    }
}
