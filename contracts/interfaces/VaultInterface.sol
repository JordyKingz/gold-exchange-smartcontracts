// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface VaultInterface {
    function withdrawTo(address to, uint amount) external;
    function deposit(uint amount) external;
    function getContractBalance() external view returns(uint);
}
