// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// WETH9  https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
// WETH10 https://etherscan.io/address/0xf4BB2e28688e89fCcE3c0580D37d36A7672E8A9F#code
// WMATIC https://polygonscan.com/address/0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270#code

interface IWETH is IERC20 {
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    function deposit() external payable;
    function withdraw(uint256 amount) external;
}