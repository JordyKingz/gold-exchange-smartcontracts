// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface GbarInterface is IERC20Upgradeable {
    function stakeBurn(address from, uint amount) external;
    function stakeMint(address to, uint amount) external;
    function goldValueMint(uint amount) external returns (bool);
}
