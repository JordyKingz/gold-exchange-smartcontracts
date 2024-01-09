pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../../contracts/providers/FeeProvider.sol";

contract FeeProviderTest is Test {
    FeeProvider public feeProvider;
    uint constant TOKEN_DECIMAL = 1e6;
    uint constant HUNDRED = 100 * TOKEN_DECIMAL;
    uint constant ONE = 1 * TOKEN_DECIMAL;
    uint constant TWENTY_FIVE = 25 * TOKEN_DECIMAL;
    uint constant FEE_PERCENTAGE = 2400;

    function setUp() public {
        feeProvider = new FeeProvider();
    }

    function test_getFee(uint128 amount) public {
        uint fee = 0;
        if (amount == 0) {
            fee = feeProvider.getFee(amount);
            assertEq(fee, 0);
        }
        if (amount > 0 && amount <= HUNDRED) {
            fee = feeProvider.getFee(amount);
            assertEq(fee, ONE * amount / HUNDRED);
        }
        if (amount > HUNDRED) {
            fee = ONE + (FEE_PERCENTAGE * amount / HUNDRED);
            if(fee > TWENTY_FIVE) {
                fee = feeProvider.getFee(amount);
                assertEq(fee, TWENTY_FIVE);
            }
            uint feeShouldBe = feeProvider.getFee(amount);
            assertEq(fee, feeShouldBe);
        }
    }
}