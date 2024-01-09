// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGBAR is IERC20 {
    function stakeBurn(address from, uint amount) external;
    function stakeMint(address to, uint amount) external;
    function goldMint(uint amount) external;
}
