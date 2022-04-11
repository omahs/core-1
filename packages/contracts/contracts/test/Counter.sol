// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./../core/component/MetaTxComponent.sol";

contract Counter is MetaTxComponent {

	uint public counter;
	address public lastCaller;

	constructor(address _forwarder) {
        _setTrustedForwarder(_forwarder);
	}

	function versionRecipient() external override pure returns (string memory) {
		return "1.0.1";
	}

	function increment() public {
		counter++;
		lastCaller = _msgSender();
	}
} 