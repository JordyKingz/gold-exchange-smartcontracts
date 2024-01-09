// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import { IFeeProvider } from "../interfaces/IFeeProvider.sol";

contract FeeProvider is IFeeProvider {
    uint constant TOKEN_DECIMAL = 1 * 10 ** 6;
    uint constant HUNDRED = 100 * TOKEN_DECIMAL;
    uint constant ONE = 1 * TOKEN_DECIMAL;
    uint constant FEE_PERCENTAGE = 2400;
    uint constant TWENTY_FIVE = 25 * TOKEN_DECIMAL;

    /**
     * @dev getFee                  Function calculate the fee for a given amount
     *
     * @param amount                The amount to calculate the fee for
     *
     * @return uint              Returns the fee for the given amount
     */
    function getFee(uint amount) external pure override returns(uint) {
        if (amount == 0) return 0;
        if (amount > 0 && amount <= HUNDRED) return ONE * amount / HUNDRED;
        if (amount > HUNDRED)
        {
            uint fee = ONE + (FEE_PERCENTAGE * amount / HUNDRED);
            if(fee > TWENTY_FIVE) return TWENTY_FIVE;
            return fee;
        }
        return 0;
    }
}
