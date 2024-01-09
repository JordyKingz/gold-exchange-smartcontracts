// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/GBAR.sol";
import "../contracts/GOLD.sol";
import "../contracts/staking/FeeDistributor.sol";
import "../contracts/providers/FeeProvider.sol";
import "../contracts/staking/GoldStakeVault.sol";
import "../contracts/oracles/MockGoldPriceOracle.sol";
import "../contracts/GBARVault.sol";

contract FeeDistributorTest is Test {
    uint128 public constant TOKEN_DECIMAL = 1 * 10 ** 6;
    uint public constant INTEREST_RATE = 50 * 10 ** 4; // 0.50% monthly interest rate
    uint public constant REWARD_FEE = 50 * 10 ** 6;
    uint public constant HUNDRED = 100 * 10 ** 6;

    FeeProvider public feeProvider;
    GOLD public goldToken;
    GBAR public gbarToken;
    GBARVault public gbarVault;
    GoldStakeVault public goldStakeVault;
    FeeDistributor public feeDistributor;
    MockGoldPriceOracle public goldPriceOracle;

    uint public blockTimestamp = block.timestamp;

    address[] public retrievalGuards;

    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);
    address public charlie = address(0x1234);
    address public dave = address(0x4321);
    address public eve = address(0x5678);
    address public company = address(0x7654);
    address public owner;

    function setUp() public {
        owner = msg.sender;

        feeProvider = new FeeProvider();
        goldToken = new GOLD();
        goldPriceOracle = new MockGoldPriceOracle();

        retrievalGuards.push(alice);
        retrievalGuards.push(bob);
        retrievalGuards.push(owner);
        gbarToken = new GBAR(address(feeProvider), 3, retrievalGuards);
        gbarVault = new GBARVault(address(gbarToken));

        goldStakeVault = new GoldStakeVault(address(goldToken), address(gbarToken));

        feeDistributor = new FeeDistributor(
            address(gbarToken),
            address(goldStakeVault),
            company,
            address(goldPriceOracle)
        );

        // Set configs
        gbarToken.setFeeDistributor(address(feeDistributor));
        gbarToken.setGBARVault(address(gbarVault));

        // Fee Exclusions
        gbarToken.addFeeExclusion(address(feeDistributor));
        gbarToken.addFeeExclusion(address(goldStakeVault));
        gbarToken.addFeeExclusion(address(gbarVault));

        goldStakeVault.setFeeDistributor(address(feeDistributor));

        goldToken.setGoldStakeVault(address(goldStakeVault));

        // increment so block.timestamp is not 0
        blockTimestamp += 1;
        vm.warp(blockTimestamp);
    }

    function testSetPayoutValuesShouldFailPeriodNotFinished() public {
        vm.expectRevert("Error: distribution period is not finished");
        feeDistributor.setPayoutValues();
    }

    function testSetPayoutValuesShouldFailAlreadyOpen() public {
        _mintGbarTokensTo(address(feeDistributor), 1000);
        vm.warp(block.timestamp + 31 days);
        feeDistributor.setPayoutValues();
        vm.expectRevert("Error: distribute is already open");
        feeDistributor.setPayoutValues();
    }

    function testSetPayoutValuesShouldFailNoFeeToDistribute() public {
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert("Error: no fee to distribute");
        feeDistributor.setPayoutValues();
    }

    function testSetPayoutValues(uint amount) public {
        vm.assume(amount > 0);
        _mint(alice, amount);
        _approve(alice, address(goldStakeVault), amount);
        _stake(alice, amount);

        _mintGbarTokensTo(address(feeDistributor), 50000 * 1e6);

        assertEq(gbarToken.balanceOf(address(feeDistributor)), 50000 * 1e6);

        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second
        feeDistributor.setPayoutValues();
        assertEq(feeDistributor.distributeOpen(), true);
        assertEq(feeDistributor.updateGoldPriceTime(), blockTimestamp + 1 hours);
        assertEq(feeDistributor.companyFeeSet(), true);
        uint goldPrice = feeDistributor.GOLD_PRICE_OUNCE();
        assertEq(goldPrice, 1927050000000000000000);
    }

    function testDistributeRewardsShouldFailNotFinished(uint128 amount) public {
        vm.assume(amount > 0);
        testSetPayoutValues(amount);
        blockTimestamp = 0;
        vm.warp(blockTimestamp);
        vm.expectRevert("Error: distribution period is not finished");
        feeDistributor.distributeRewards();
    }

    // distribute not open
    function testDistributeRewardsShouldFailDistributeNotOpen() public {
        _mintGbarTokensTo(address(feeDistributor), 50000 * 1e6);

        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second

        vm.expectRevert("Error: distribute is not open");
        feeDistributor.distributeRewards();
    }

    function testDistributeRewardsShouldFailNoGoldPriceNotUpdated(uint128 amount) public {
        vm.assume(amount > 0);
        testSetPayoutValues(amount);

        blockTimestamp += 2 hours;
        vm.warp(blockTimestamp);

        vm.expectRevert("Error: gold price needs to be updated");
        feeDistributor.distributeRewards();
    }

    function testDistributeRewardsShouldFailNoFeeToDistribute(uint128 amount) public {
        vm.assume(amount > 0);
        testSetPayoutValues(amount);

        _burnGbarBalance(address(feeDistributor));
        vm.expectRevert("Error: no fee to distribute");
        feeDistributor.distributeRewards();
    }

    function testDistributeRewardsShouldFailNoGoldStaked() public {
        _mintGbarTokensTo(address(feeDistributor), 50000 * 1e6);
        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second
        feeDistributor.setPayoutValues();
        vm.expectRevert("Error: no gold staked");
        feeDistributor.distributeRewards();
    }

    function testDistributeRewards(uint128 amount) public {
        vm.assume(amount > 0);

        testSetPayoutValues(amount);

        // calculate how much reward should be sent to goldStakeVault
        uint goldPrice = feeDistributor.GOLD_PRICE_OUNCE();
        uint distributorBalance = gbarToken.balanceOf(address(feeDistributor));
        uint totalGoldStaked = goldStakeVault.totalSupply(); // amount
        uint ounceToGramInWei = 31103476800000000000;
        uint goldPriceInGram = goldPrice / ounceToGramInWei;
        uint totalValueOfGoldStaked = (totalGoldStaked * goldPriceInGram) * uint(TOKEN_DECIMAL);

        uint maxRewardsToDistribute = (distributorBalance * REWARD_FEE) / HUNDRED;
        uint interestToPay = (totalValueOfGoldStaked * INTEREST_RATE) / HUNDRED;

        bool payoutMaxReward = false;
        if (interestToPay > maxRewardsToDistribute) {
            payoutMaxReward = true;
            interestToPay = maxRewardsToDistribute;
        }

        feeDistributor.distributeRewards();
        assertEq(feeDistributor.distributeOpen(), false);
        assertEq(feeDistributor.periodFinish(), blockTimestamp + 1 days);
        assertEq(feeDistributor.distributePeriod(), 1);

        uint goldStakeVaultBalance = gbarToken.balanceOf(address(goldStakeVault));

        if (payoutMaxReward) {
            assertEq(goldStakeVaultBalance, maxRewardsToDistribute);
        } else {
            assertEq(goldStakeVaultBalance, interestToPay);
        }
    }

    function testSetGbarTokenShouldFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.setGbarToken(address(gbarToken));
    }

    function testSetGbarTokenShouldFailAddressZero() public {
        vm.expectRevert("Error: gbar token address is zero");
        feeDistributor.setGbarToken(address(0));
    }

    function testSetGbarToken(address gbarTokenAddress) public {
        IERC20 gbarTokenBefore = feeDistributor.IGbarToken();
        assertEq(address(gbarTokenBefore), address(gbarToken));

        vm.assume(gbarTokenAddress != address(0));
        feeDistributor.setGbarToken(gbarTokenAddress);
        IERC20 gbarTokenAfter = feeDistributor.IGbarToken();
        assertEq(address(gbarTokenAfter), gbarTokenAddress);
    }

    function testSetGoldStakeVaultShouldFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.setGoldStakeVault(address(goldStakeVault));
    }

    function testSetGoldStakeVaultShouldFailAddressZero() public {
        vm.expectRevert("Error: gold stake vault address is zero");
        feeDistributor.setGoldStakeVault(address(0));
    }

    function testSetgoldStakeVault(address stakeVault) public {
        IGoldStakeVault vaultBefore = feeDistributor.GOLD_STAKE_VAULT();
        assertEq(address(vaultBefore), address(goldStakeVault));

        vm.assume(stakeVault != address(0));
        feeDistributor.setGoldStakeVault(stakeVault);
        IGoldStakeVault vaultAfter = feeDistributor.GOLD_STAKE_VAULT();
        assertEq(address(vaultAfter), stakeVault);
    }

    function testSetCompanyShouldFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.setCompany(address(alice));
    }

    function testSetCompanyShouldFailAddressZero() public {
        vm.expectRevert("Error: company address is zero");
        feeDistributor.setCompany(address(0));
    }

    function testSetCompany(address _company) public {
        address companyBefore = feeDistributor.COMPANY();
        assertEq(companyBefore, company);

        vm.assume(company != address(0));
        feeDistributor.setCompany(_company);
        address companyAfter = feeDistributor.COMPANY();
        assertEq(companyAfter, _company);
    }

    function testSendAllFeesToGoldVaultShoudFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.sendAllFeesToGoldVault();
    }

    function testSendAllFeesToGoldVaultShouldFailNoFeeToDistribute() public {
        vm.expectRevert("Error: no fee to distribute");
        feeDistributor.sendAllFeesToGoldVault();
    }

    function testSendAllFeesToGoldVault() public {
        _mintGbarTokensTo(address(feeDistributor), 50000 * 1e6);

        uint balanceBefore = gbarToken.balanceOf(address(goldStakeVault));
        feeDistributor.sendAllFeesToGoldVault();
        uint balanceAfter = gbarToken.balanceOf(address(goldStakeVault));
        assertEq(balanceAfter, balanceBefore + 50000 * 1e6);
    }

    function testPayCompanyShouldFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.payCompany();
    }

    function testPayCompanyShouldFailDistributionPeriodNotFinished() public {
        vm.expectRevert("Error: distribution period not finished");
        feeDistributor.payCompany();
    }

    function testPayCompanyShouldFailCompanyFeeNotSet() public {
        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second
        vm.expectRevert("Error: company fee not set");
        feeDistributor.payCompany();
    }

    function testPayCompanyShouldFailCompanyFeeIsZero() public {
        _mintGbarTokensTo(address(feeDistributor), 1); // 1 token and 50% is distribute, sets company fee to 0
        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second

        feeDistributor.setPayoutValues();

        vm.expectRevert("Error: company fee is zero");
        feeDistributor.payCompany();
    }

    function testPayCompany() public {
        _mintGbarTokensTo(address(feeDistributor), 50000 * 1e6);
        blockTimestamp += 31 days;
        vm.warp(blockTimestamp); // 31 days, 1 second

        feeDistributor.setPayoutValues();

        feeDistributor.payCompany();

        uint companyBalance = gbarToken.balanceOf(company);
        assertEq(companyBalance, 25000 * 1e6); // 50% is distributed to company
    }

    function _mintGbarTokensTo(address to, uint128 amount) internal {
        gbarToken.mint(amount);
        gbarVault.withdrawTo(to, amount);
    }

    function _burnGbarBalance(address account) internal {
        gbarToken.addBlacklist(account); // only burnable from blacklisted wallets.
        uint balance = gbarToken.balanceOf(account);
        gbarToken.burn(account, balance);
    }

    function _mint(address to, uint amount) internal {
        goldToken.mint(to, amount);
    }

    function _approve(address _owner, address spender, uint amount) internal {
        vm.prank(_owner);
        goldToken.approve(spender, amount);
    }

    function _stake(address _owner, uint amount) internal {
        vm.prank(_owner);
        goldStakeVault.stake(amount);
    }
}
