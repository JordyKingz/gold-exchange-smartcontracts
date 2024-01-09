// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IGoldPriceOracle.sol";

/// @notice Chainlink oracle for XAU/USD
contract GoldPriceOracle is IGoldPriceOracle {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // XAU/USD mainnet
        priceFeed = AggregatorV3Interface(
            0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6
        );
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
        ,
        /*uint80 roundID*/ int price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
        ,
        ,

        ) = priceFeed.latestRoundData();
        return price;
    }
}
