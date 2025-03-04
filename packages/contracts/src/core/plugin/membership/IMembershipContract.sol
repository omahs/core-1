// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IDAO} from "../../dao/IDAO.sol";

/// @notice An interface to be implemented by DAO plugins that define membership based on a contract. This can be
/// - a token contract (e.g., (Governance-) ERC-20 and ERC-721) defining membership based on ownership / delegation.
/// - a registry contract (e.g, `Addresslist`, the Proof of Humanity Registry) defining membership by curation of a list.
interface IMembershipContract {
    /// @notice Emitted to announce the membership being defined by a contract.
    /// @param definingContract The contract defining the membership.
    event MembershipContractAnnounced(address indexed definingContract);

    /// @notice Checks if an account is a member of the DAO.
    /// @param _account The address of the account to be checked.
    /// @return Whether the account is a member or not.
    /// @dev This function must be implemented in the plugin contract that introduces the members to the DAO.
    function isMember(address _account) external view returns (bool);
}
