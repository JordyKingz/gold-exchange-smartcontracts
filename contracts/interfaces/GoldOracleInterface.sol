// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface GoldOracleInterface {
    function lastUpdateTimestamp() external view returns (uint);
    function getLatestPrice() external view returns (int);
    function getGoldGbarConversion(uint amount) external view returns (uint256, uint256, uint256);
}
