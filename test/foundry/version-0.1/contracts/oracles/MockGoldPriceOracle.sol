// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "../interfaces/IGoldPriceOracle.sol";

contract MockGoldPriceOracle is IGoldPriceOracle {
    constructor() {}

    /**
     * @dev getLatestPrice         Function to mock the latest price of gold
     *
     * @notice                     This function is only for testing purposes
     *
     * @dev last updated:          March 15, 14:30 CET
     *
     * @return int                 $1,927.05 per ounce
     */
    function getLatestPrice() public pure returns (int) {
        return 192705;
    }
}
