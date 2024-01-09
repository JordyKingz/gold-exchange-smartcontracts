// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/GoldOracleInterface.sol";

// todo: Change of Gold Token Value... Was 1 token = 1 gram, now 1 token = 1 ounce... ):
contract GoldPriceOracle is GoldOracleInterface, Ownable {
    int public latestPrice;
    uint public lastUpdateTimestamp;

    uint256 public constant ounceToGramInWei = 31103476800000000000;

    event PriceUpdated(int _latestPrice, uint _lastUpdateTimestamp);
    error GoldPriceNotSet();
    error PriceCannotBeZero();
    error AmountCannotBeZero();
    error ExceedsMaxValue();

    constructor(int _latestPrice) {
        lastUpdateTimestamp = block.timestamp;
        latestPrice = _latestPrice;
    }

    /**
     * @dev getLatestPrice         Function to get the latest price of gold
     *
     * @notice                     Chainlink is not on Hedera yet, so we use our own oracle
     *
     * @return int
     */
    function getLatestPrice() public view returns (int) {
        if (latestPrice == 0) {
            revert GoldPriceNotSet();
        }
        return latestPrice;
    }

    /**
     * @dev setLatestPrice         Function to set new Gold price
     *
     * @param _latestPrice         New price of gold
     */
    function setLatestPrice(int _latestPrice) public onlyOwner {
        if (_latestPrice == 0) {
            revert PriceCannotBeZero();
        }
        lastUpdateTimestamp = block.timestamp;
        latestPrice = _latestPrice;
        emit PriceUpdated(latestPrice, lastUpdateTimestamp);
    }

    /**
     * @dev getGoldGbarConversion       Function to calculate the value of gold in GBAR
     *
     * @param amount                    Amount of gold in grams
     *
     * @return uint, uint, uint         Gold price in grams, total value of gold, GBAR value
     */
    function getGoldGbarConversion(uint amount) public view returns (uint256, uint256, uint256) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > 1000000000) { // 1 billion grams of gold 64.8B USD
            revert ExceedsMaxValue();
        }
        int goldPrice = getLatestPrice();

        uint goldPriceInOunce = uint256(goldPrice) * 1e24; // 195928965000000000000000000000000000
        uint256 ounceToGramInWei = ounceToGramInWei * 1e8; // 3110347680000000000000000000
        uint256 goldPriceInGram = goldPriceInOunce / ounceToGramInWei; // 62992600 (62.9926 USD) 1kg gold = $62.992,600000

        uint256 totalValueOfGold = amount * (goldPriceInGram);

        uint256 gbarValue = (totalValueOfGold * 85) / 100;
        return (goldPriceInGram, totalValueOfGold, gbarValue);
    }
}
