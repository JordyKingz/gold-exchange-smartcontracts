// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface FeeProviderInterface {
    function getFee(uint amount) external view returns (uint);
}
