// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../utils/TimeHelpers.sol";
import "./Paymaster.sol";

/// @title todo
/// @author Michael Heuer - Aragon Association - 2022
/// @notice todo
abstract contract IStreamPaymaster is Paymaster, TimeHelpers {

    mapping (address => uint64) cooldown;

    error CooldownNotOver(uint64 expected);


    function streamActive() virtual public view returns (bool);
    function streamBalance() virtual public view returns (uint256);
    function withdrawFromStream() virtual public;

    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    override
    virtual
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (signature, maxPossibleGas); //to silence warnings

        // TODO explanation
        if(approvalData.length != 0 
        || relayRequest.relayData.paymasterData.length != 0) {
            revert InvalidApprovalLength({
                approvalDataLength: approvalData.length, 
                relayedPaymasterDataLength: relayRequest.relayData.paymasterData.length
            });
        }

        if(!dao.hasPermission(
                relayRequest.request.to,
                relayRequest.request.from,
                PAYMASTER_SPONSORED_ROLE,
                relayRequest.relayData.paymasterData
            )
        ) {
            revert ACLData.ACLAuth({
                here: address(this),
                where: relayRequest.request.to,
                who: relayRequest.request.from,
                role: PAYMASTER_SPONSORED_ROLE
            });
        }

        // check cooldown
        uint64 currentTime = getTimestamp64();

        if(cooldown[relayRequest.request.from] > currentTime)
            revert CooldownNotOver(cooldown[relayRequest.request.from]);

        cooldown[relayRequest.request.from] = currentTime + 5 minutes;

        if(streamActive()){
            withdrawFromStream();
        }

        return ("", false);
    }

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) external override virtual {
        (context, success, gasUseWithoutPost, relayData);
    }

}
