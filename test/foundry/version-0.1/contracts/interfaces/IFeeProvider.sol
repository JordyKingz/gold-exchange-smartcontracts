// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

interface IFeeProvider{
    function getFee(uint amount) external view returns (uint);
}
