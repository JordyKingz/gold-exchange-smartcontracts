// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

interface IGBARVault {
    function withdrawTo(address to, uint amount) external;
    function deposit(uint amount) external;
    function getContractBalance() external view returns(uint);
}
