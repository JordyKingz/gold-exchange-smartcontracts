pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../../contracts/oracles/GoldOracle.sol";

contract GoldPriceOracleTest is Test {
    GoldPriceOracle public oracle;
    uint256 public constant ounceToGramInWei = 31103476800000000000;

    address public alice = address(0x1);

    error GoldPriceNotSet();
    error PriceCannotBeZero();
    error AmountCannotBeZero();
    error ExceedsMaxValue();

    function setUp() public {
        oracle = new GoldPriceOracle(198806100000);
    }

    function test_getLatestPrice() public {
        int price = oracle.getLatestPrice();
        assertEq(price, 198806100000);
    }

    function test_getOwner() public {
        address owner = oracle.owner();
        assertEq(owner, address(this));
    }

    function test_getOunceToGramInWei() public {
        uint256 _ounceToGramInWei = oracle.ounceToGramInWei();
        assertEq(_ounceToGramInWei, ounceToGramInWei);
    }

    function test_setLatestPrice(int goldPrice) public {
        vm.assume(goldPrice > 0);
        oracle.setLatestPrice(goldPrice);
        int price = oracle.getLatestPrice();
        assertEq(price, goldPrice);
    }

    function test_setLatestPriceZero() public {
        vm.expectRevert(PriceCannotBeZero.selector);
        oracle.setLatestPrice(0);
    }

    function test_setLatestPriceNoOwner(int goldPrice) public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setLatestPrice(goldPrice);
    }

    function test_getGoldGbarConversion(uint amount) public {
        vm.assume(amount > 0 && amount < 1000000000); // 1 billion grams of gold
        int goldPrice = oracle.getLatestPrice();
        uint goldPriceInOunce = uint256(goldPrice) * 1e18;
        uint256 goldPriceInGram = ((goldPriceInOunce / ounceToGramInWei) * 1e6) / 1e8;
        uint256 totalValueOfGold = amount * (goldPriceInGram);
        uint256 gbarValue =  (totalValueOfGold * 85) / 100;
        (uint256 _goldPriceInGram, uint256 _totalValueOfGold, uint256 _gbarValue) = oracle.getGoldGbarConversion(amount);
        assertEq(_goldPriceInGram, goldPriceInGram);
        assertEq(_totalValueOfGold, totalValueOfGold);
        assertEq(_gbarValue, gbarValue);
    }

    function test_getGoldGbarConversionAmountZero() public {
        vm.expectRevert(AmountCannotBeZero.selector);
        oracle.getGoldGbarConversion(0);
    }

    function test_getGoldGbarConversionAmountExceedsMaxValue(uint amount) public {
        vm.assume(amount > 1000000000); // 1 billion grams of gold
        vm.expectRevert(ExceedsMaxValue.selector);
        oracle.getGoldGbarConversion(amount);
    }
}