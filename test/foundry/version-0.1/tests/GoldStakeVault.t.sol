pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/providers/FeeProvider.sol";
import "../contracts/GBAR.sol";
import "../contracts/GBARVault.sol";
import "../contracts/staking/FeeDistributor.sol";
import "../contracts/staking/GoldStakeVault.sol";
import "../contracts/GOLD.sol";
import "../contracts/oracles/MockGoldPriceOracle.sol";

contract GoldStakeVaultTest is Test {
    uint256 public constant ONE = 1 * (1 * 10 ** 6); // used to calculate rewards
    uint128 public constant TOKEN_DECIMAL = 1 * 10 ** 6;

    FeeProvider public feeProvider;
    GBAR public gbar;
    GBARVault public gbarVault;
    FeeDistributor public feeDistributor;
    GoldStakeVault public goldStakeVault;
    GOLD public goldToken;
    MockGoldPriceOracle public oracle;

    address[] public retrievalGuards;

    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);
    address public charlie = address(0x4321);
    address public dave = address(0x2233);

    address public owner = address(0x1234);
    address public company = address(0x7654);

    function setUp() public {
        owner = msg.sender;
        feeProvider = new FeeProvider();
        goldToken = new GOLD();
        oracle = new MockGoldPriceOracle();

        // Deploy GBAR
        retrievalGuards.push(alice);
        retrievalGuards.push(bob);
        retrievalGuards.push(owner);
        // fee provider is set in constructor
        gbar = new GBAR(address(feeProvider), 3, retrievalGuards);

        gbarVault = new GBARVault(address(gbar));
        goldStakeVault = new GoldStakeVault(address(goldToken), address(gbar));

        // Deploy FeeDistributor
        feeDistributor = new FeeDistributor(address(gbar),
            address(goldStakeVault),
            company,
            address(oracle));

        // Set configs
        gbar.setFeeDistributor(address(feeDistributor));
        gbar.setGBARVault(address(gbarVault));
        gbar.setFeeProvider(address(feeProvider));

        // Fee Exclusions
        gbar.addFeeExclusion(address(feeDistributor));
        gbar.addFeeExclusion(address(goldStakeVault));
        gbar.addFeeExclusion(address(gbarVault));

        goldStakeVault.setFeeDistributor(address(feeDistributor));

        goldToken.setGoldStakeVault(address(goldStakeVault));

        // increment so block.timestamp is not 0
        vm.warp(block.timestamp + 1 seconds);
    }

//    function testDistributionPeriod() public {
//        uint distributionPeriod = goldStakeVault.DISTRIBUTION_PERIOD();
//        assertEq(distributionPeriod, 30 days);
//    }

//    function testPeriodFinish() public {
//        uint periodFinish = goldStakeVault.periodFinish();
//        assertEq(periodFinish, 0);
//    }

    function testRewardRate() public {
        uint rewardRate = goldStakeVault.rewardRate();
        assertEq(rewardRate, 0);
    }

    function testLastUpdateTime() public {
        uint lastUpdateTime = goldStakeVault.lastUpdateTime();
        assertEq(lastUpdateTime, 0);
    }

    function testRewardPerTokenStored() public {
        uint rewardPerTokenStored = goldStakeVault.rewardPerTokenStored();
        assertEq(rewardPerTokenStored, 0);
    }

    function testTotalStakers() public {
        uint totalStakers = goldStakeVault.totalStakers();
        assertEq(totalStakers, 0);
    }

    function testTotalSupply() public {
        uint totalSupply = goldStakeVault.totalSupply();
        assertEq(totalSupply, 0);
    }

    function testBalanceOf() public {
        uint balance = goldStakeVault.balanceOf(address(this));
        assertEq(balance, 0);
    }

//    function testLastTimeRewardApplicable() public {
//        uint lastTimeRewardApplicable = goldStakeVault.lastTimeRewardApplicable();
//        uint periodFinish = goldStakeVault.periodFinish();
//        assertEq(lastTimeRewardApplicable, periodFinish);
//    }

    function testRewardPerToken() public {
        uint rewardPerToken = goldStakeVault.rewardPerToken();
        assertEq(rewardPerToken, 0);
    }

    function testGetRewardForDuration() public {
        uint rewardsForDuration = goldStakeVault.getRewardForDuration();
        assertEq(rewardsForDuration, 0);
    }

    function testGetEntryIndexer() public {
        uint[] memory entryIndexer = goldStakeVault.getEntryIndexer();
        assertEq(entryIndexer.length, 0);
    }

    function testGetEntryIndexerForAddress() public {
        uint[] memory entryIndexer = goldStakeVault.getEntryIndexerForAddress(address(this));
        assertEq(entryIndexer.length, 0);
    }

    function testGetStakeEntryNonExistent() public {
        vm.expectRevert("Error: Entry does not exist");
        goldStakeVault.getStakeEntry(1);
    }

    function testGetStakeEntryForAddressNonExistent() public {
        vm.expectRevert("Error: Entry does not exist");
        goldStakeVault.getStakeEntryForAddress(address(this), 1);
    }

    function testGetStakeEntry(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 5_000_000 * 10 ** 6);

        _mintTokensTo(alice, amount);
        _approveTokens(alice, amount);

        vm.startPrank(alice);
        // create the stake entry
        _createStakeEntry(amount);

        _verifyStakeEntry(1, amount, alice);
        vm.stopPrank();
    }

    function testEarned() public {
        _mintTokensTo(alice, 100); // 100 g gold
        _approveTokens(alice, 100);
        _mintTokensTo(bob, 100); // 100 g gold
        _approveTokens(bob, 100);

        vm.startPrank(alice);
        // create the stake entry
        _createStakeEntry(100);
        // id for staker, amount, staker
        _verifyStakeEntry(1, 100, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        // create the stake entry
        _createStakeEntry(100);
        // id for staker, amount, staker
        _verifyStakeEntry(1, 100, alice);
        vm.stopPrank();

        // 100.000 GBAR Transactions = 37200000 fees
        _notifyAndWarp(100000 * TOKEN_DECIMAL);

        uint256 earnedAlice = goldStakeVault.earned(alice);
        uint256 earnedShouldBeAlice = _calculateRewards(alice);
        assertEq(earnedAlice, earnedShouldBeAlice);

        uint256 earnedBob = goldStakeVault.earned(bob);
        uint256 earnedShouldBeBob = _calculateRewards(bob);
        assertEq(earnedBob, earnedShouldBeBob);
    }

    function testClaimRewards(uint128 amount) public {
        vm.assume(amount > 1 * TOKEN_DECIMAL);
        _mintTokensTo(alice, 1); // 1 g gold
        _approveTokens(alice, 1);
        _mintTokensTo(bob, 1); // 1 g gold
        _approveTokens(bob, 1);

        vm.startPrank(alice);
        // create the stake entry
        _createStakeEntry(1);
        // id for staker, amount, staker
        _verifyStakeEntry(1, 1, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        // create the stake entry
        _createStakeEntry(1);
        // id for staker, amount, staker
        _verifyStakeEntry(1, 1, alice);
        vm.stopPrank();

        _notifyAndWarp(amount);

        uint256 earnedAlice = goldStakeVault.earned(alice);
        uint256 earnedShouldBeAlice = _calculateRewards(alice);
        assertEq(earnedAlice, earnedShouldBeAlice);

        uint256 earnedBob = goldStakeVault.earned(bob);
        uint256 earnedShouldBeBob = _calculateRewards(bob);
        assertEq(earnedBob, earnedShouldBeBob);

        // balances before
        uint256 aliceBalanceBefore = gbar.balanceOf(alice);
        uint256 bobBalanceBefore = gbar.balanceOf(bob);

        vm.prank(alice);
        goldStakeVault.claimRewards();
        vm.prank(bob);
        goldStakeVault.claimRewards();

        uint256 aliceBalanceAfter = gbar.balanceOf(alice);
        assertEq(aliceBalanceAfter, (aliceBalanceBefore + earnedShouldBeAlice));
        uint256 bobBalanceAfter = gbar.balanceOf(bob);
        assertEq(bobBalanceAfter, (bobBalanceBefore + earnedShouldBeBob));
    }

    function testStakeShouldFailAmountZero() public {
        _mintTokensTo(alice, 1); // 1 g gold
        _approveTokens(alice, 1);

        vm.prank(alice);
        vm.expectRevert("Error: Amount must be > 0");
        _createStakeEntry(0);
    }

    function testStakeShouldFailTokensNotEnough() public {
        _mintTokensTo(alice, 1); // 1 g gold
        _approveTokens(alice, 1);

        vm.prank(alice);
        vm.expectRevert("Error: Insufficient balance");
        _createStakeEntry(2);
    }

    function testStakeShouldFailTokensNotApproved() public {
        _mintTokensTo(alice, 1); // 1 g gold

        vm.prank(alice);
        vm.expectRevert("Error: Transfer of token has not been approved");
        _createStakeEntry(1);
    }

    function testStake(uint256 amount) public {
        vm.assume(amount > 0);
        _mintTokensTo(alice, amount);
        _approveTokens(alice, amount);

        vm.startPrank(alice);
        _createStakeEntry(amount);
        _verifyStakeEntry(1, amount, alice);
        vm.stopPrank();
    }

    function testMintStakeShouldFailAmountZero() public {
        vm.prank(address(goldToken));
        vm.expectRevert("Error: Amount must be > 0");
        goldStakeVault.mintStake(0, alice);
    }

    function testMintStakeShouldFailNotApproved() public {
        vm.prank(address(goldToken));
        vm.expectRevert("Error: Transfer of token has not been approved");
        goldStakeVault.mintStake(1, alice);
    }

    function testMintStake(uint amount) public {
        vm.assume(amount > 0);
        goldToken.stakeMint(amount, alice);

        uint stakeBalance = goldStakeVault.balanceOf(alice);
        assertEq(stakeBalance, amount);
    }

    function testWithdrawGoldShouldFailNoValidEntry() public {
        vm.prank(alice);
        vm.expectRevert("Error: Entry does not exist");
        goldStakeVault.withdrawGold(1);
    }

    function testWithdrawGoldShouldFailEmptyEntry(uint256 amount) public {
        vm.assume(amount > 0);
        _mintTokensTo(alice, amount);
        _approveTokens(alice, amount);
        vm.startPrank(alice);
        _createStakeEntry(amount);
        _verifyStakeEntry(1, amount, alice);

        // withdraw
        goldStakeVault.withdrawGold(1);
        vm.expectRevert("Error: Empty entry");
        goldStakeVault.withdrawGold(1);
        vm.stopPrank();
    }

    function testWithdrawGold(uint128 amount) public {
        vm.assume(amount > 1 * TOKEN_DECIMAL);
        _mintTokensTo(alice, amount);
        _approveTokens(alice, amount);

        vm.startPrank(alice);
        _createStakeEntry(amount);
        _verifyStakeEntry(1, amount, alice);
        vm.stopPrank();

        uint totalStakersBefore = goldStakeVault.totalStakers();
        assertEq(totalStakersBefore, 1);

        _notifyAndWarp(amount);

        uint earnedAlice = goldStakeVault.earned(alice);
        uint earnedShouldBeAlice = _calculateRewards(alice);
        assertEq(earnedAlice, earnedShouldBeAlice);

        uint rewardForAlice = goldStakeVault.Rewards(alice);
        assertEq(rewardForAlice, earnedShouldBeAlice);

        uint aliceGbarBalanceBefore = gbar.balanceOf(alice);

        // withdraw
        vm.prank(alice);
        goldStakeVault.withdrawGold(1);

        // gbar balance must be increased with rewards
        uint aliceGbarBalanceAfter = gbar.balanceOf(alice);
        assertEq(aliceGbarBalanceAfter, (aliceGbarBalanceBefore + earnedShouldBeAlice));

        // rewards for alice must be 0
        uint rewardForAliceAfter = goldStakeVault.Rewards(alice);
        assertEq(rewardForAliceAfter, 0);

        // check if gold is back in alice wallet
        uint aliceGoldBalance = goldToken.balanceOf(alice);
        assertEq(aliceGoldBalance, amount);

        // check if amount is set to 0
        vm.prank(alice);
        Entry memory entry = goldStakeVault.getStakeEntry(1);
        assertEq(entry.amount, 0);

        uint totalStakersAfter = goldStakeVault.totalStakers();
        assertEq(totalStakersAfter, 0);
    }

    function testNotifyRewardAmountShouldFailAmountZero() public {
        vm.prank(address(feeDistributor));
        vm.expectRevert("Reward cannot be 0");
        goldStakeVault.notifyRewardAmount(0);
    }

    function testNotifyRewardAmountShouldFailNotDistributorOrOwner() public {
        vm.prank(alice);
        vm.expectRevert("Error: Only FeeDistributor contract or Owner can call this function");
        goldStakeVault.notifyRewardAmount(10000 * TOKEN_DECIMAL);
    }

    function testNotifyRewardAmountShouldFailProvidedRewardTooHigh() public {
        vm.warp(block.timestamp + 31 days);

        vm.prank(address(feeDistributor));
        vm.expectRevert("Provided reward too high");
        goldStakeVault.notifyRewardAmount(10000 * TOKEN_DECIMAL);
    }

    function testNotifyRewardAmount(uint128 amount) public {
        vm.assume(amount > 1 * TOKEN_DECIMAL);
        _mintGbarTokensTo(address(goldStakeVault), amount);

        vm.warp(block.timestamp + 31 days);

        uint distributorBalance = gbar.balanceOf(address(goldStakeVault));
        assertEq(distributorBalance, amount);

        vm.prank(address(feeDistributor));
        goldStakeVault.notifyRewardAmount(amount);

        // calculate reward rate
        uint rewardRate = amount;
        assertEq(rewardRate, goldStakeVault.rewardRate());

        uint balance = distributorBalance;
        assertEq(rewardRate, balance);
    }

    function testSetFeeDistributorShouldFailNoOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        goldStakeVault.setFeeDistributor(bob);
    }

    function testSetFeeDistributorShouldFailAddressZero() public {
        vm.expectRevert("Error: Fee Distributor cannot be 0 address");
        goldStakeVault.setFeeDistributor(address(0));
    }

    function testSetFeeDistributor() public {
        goldStakeVault.setFeeDistributor(bob);
        assertEq(goldStakeVault.FEE_DISTRIBUTOR(), bob);
    }

    function testRecoverERC20ShouldFailNoOwner() public {
        uint amount = 1000;
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        goldStakeVault.recoverERC20(address(gbar), amount);
    }

    function testRecoverERC20ShouldFailStakeToken() public {
        uint amount = 1000;
        vm.expectRevert("Cannot withdraw the staking token");
        goldStakeVault.recoverERC20(address(goldToken), amount);
    }

    function testRecoverERC20() public {
        uint128 amount = 1000;
        _mintGbarTokensTo(alice, amount);

        vm.prank(alice);
        gbar.transfer(address(goldStakeVault), amount);

        // should be 0
        uint ownerBalanceBefore = gbar.balanceOf(address(this));
        assertEq(ownerBalanceBefore, 0);

        // prank is over, back to owner
        // recover sends tokens to owner of stakeVault
        goldStakeVault.recoverERC20(address(gbar), amount);
        // 1000
        uint ownerBalanceAfter = gbar.balanceOf(address(this));
        // 1000 = 0 + 1000
        assertEq(ownerBalanceAfter, ownerBalanceBefore + amount);
    }

    function _mintTokensTo(address to, uint256 amount) internal {
        goldToken.mint(to, amount);
    }

    function _mintGbarTokensTo(address to, uint128 amount) internal {
        // minted gbar is sent to gbarVault
        gbar.mint(amount);
        gbarVault.withdrawTo(to, amount);
    }

    function _approveTokens(address spender, uint256 amount) internal {
        vm.prank(spender);
        goldToken.approve(address(goldStakeVault), amount);
    }

    function _createStakeEntry(uint256 amount) internal {
        goldStakeVault.stake(amount);
    }

    function _verifyStakeEntry(uint id, uint amount, address staker) internal {
        Entry memory entry = goldStakeVault.getStakeEntry(id);
        assertEq(entry.amount, amount);
        Entry memory entryAddress = goldStakeVault.getStakeEntryForAddress(staker, id);
        assertEq(entryAddress.amount, amount);
    }

    function _notifyAndWarp(uint128 amount) internal {
        vm.assume(amount > 1 * TOKEN_DECIMAL);
        assertEq(block.timestamp, 2);
//        assertEq(goldStakeVault.periodFinish(), 0);
        _transferTokensToEarnFee(amount);

        // warp 30 days, so duration is finished
        vm.warp(block.timestamp + (30 days + 1 seconds));

        // transfer gbar from distributor to stakevault
        feeDistributor.setPayoutValues();
        feeDistributor.distributeRewards();
    }

    function _transferTokensToEarnFee(uint128 amount) internal returns (uint feeBalance) {
        vm.assume(amount > 1 * TOKEN_DECIMAL);
        _mintGbarTokensTo(alice, amount);
        _mintGbarTokensTo(bob, amount);
        _mintGbarTokensTo(charlie, amount);
        _mintGbarTokensTo(dave, amount);

        uint128 transferAmount = amount / 10;

        uint feeShouldBe = 0;
        for(uint i = 0; i < 5; i++) {
            vm.startPrank(alice);
            gbar.transfer(bob, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            gbar.transfer(charlie, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            vm.stopPrank();

            vm.startPrank(bob);
            gbar.transfer(charlie, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            gbar.transfer(alice, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            vm.stopPrank();

            vm.startPrank(charlie);
            gbar.transfer(bob, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            gbar.transfer(alice, transferAmount);
            feeShouldBe += feeProvider.getFee(transferAmount);
            vm.stopPrank();
        }

        feeBalance = gbar.balanceOf(address(feeDistributor));
        assertEq(feeBalance, feeShouldBe);
    }

    function _calculateRewards(address staker) internal view returns (uint reward) {
        uint256 accountBalance = goldStakeVault.balanceOf(staker);
        uint256 rewardPerToken = goldStakeVault.rewardPerToken();
        uint256 rewardPerTokenPaid = goldStakeVault.UserRewardPerTokenPaid(staker);
        uint256 rewardsForAccount = goldStakeVault.Rewards(staker);

        reward = ((accountBalance * (rewardPerToken - rewardPerTokenPaid)) / ONE) + rewardsForAccount;
    }
}