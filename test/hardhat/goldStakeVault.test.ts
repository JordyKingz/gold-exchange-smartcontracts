import {ethers} from "hardhat";
import {deployAllContracts, getLatestGoldPriceMainnet} from "../../scripts/utils/helpers";
import {expect} from "chai";

let goldPriceOracle: any;
let feeProvider: any;
let goldToken: any;
let gbarToken: any;
let gbarVault: any;
let goldVault: any;
let feeDistributor: any;
let goldStakeVault: any;

let owner: any;
let alice: any;
let bob: any;
let charlie: any;
let dave: any;
let company: any;

let retrievalGuardList: string[] = [];

//
const MIN_AMOUNT = 90;
const MAX_AMOUNT = 1000000;

function getRandomInt(min: number, max: number) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min + 1) + min);
}

async function mintGbar(to: any, amount: any) {
  await gbarToken.connect(owner).mint(amount);
  await gbarVault.connect(owner).withdrawTo(to.address, amount);
}

async function makeGbarTransactions(numTransactions: number) {
  const users = [alice, bob, charlie, dave];
  const minUserIndex = 0;
  const maxUserIndex = users.length - 1;
  let fee: any = 0;

  for (let i = 0; i < numTransactions; i++) {
    // Choose a random user to send tokens from and to
    const fromIndex = getRandomInt(minUserIndex, maxUserIndex);
    const toIndex = getRandomInt(minUserIndex, maxUserIndex);
    // Choose a random amount between MIN_AMOUNT and MAX_AMOUNT
    let amount: any = getRandomInt(MIN_AMOUNT, MAX_AMOUNT);
    amount = ethers.utils.parseUnits(amount.toString(), 6);
    await mintGbar(users[fromIndex], amount);

    const txFee = await feeProvider.getFee(amount);
    fee += Number(ethers.utils.formatUnits(txFee, 6));

    // Send the tokens from the sender to the recipient
    await gbarToken.connect(users[fromIndex]).transfer(users[toIndex].address, amount);
  }
  // convert fee to 6 decimals to prevent overflow/underflow errors
  fee = fee.toFixed(6);

  // check if fee distributor has right balance
  const feeDistributorBalance = await gbarToken.balanceOf(feeDistributor.address);
  expect(feeDistributorBalance).to.equal(ethers.utils.parseUnits(fee.toString(), 6));
}

async function updateGoldPriceOracle() {
  /// @notice we as Gold Exchange run our own Oracle node, so we update the Gold price manually
  /// this will happen automatically in production, based on the last update time in the oracle
  const result = await getLatestGoldPriceMainnet();
  await goldPriceOracle.setLatestPrice(result.price);
}

describe("Gold Stake Vault Contract", function () {
  before(async function () {
    [
      owner,
      alice,
      bob,
      charlie,
      dave,
      company,
    ] = await ethers.getSigners();
    /// @notice deploys all contracts and sets their configs
    const result = await deployAllContracts(owner, charlie, dave, company);
    goldPriceOracle = result.goldPriceOracle;
    feeProvider = result.feeProvider;
    goldToken = result.goldToken;
    gbarToken = result.gbarToken;
    gbarVault = result.gbarVault;
    feeDistributor = result.feeDistributor;
    goldStakeVault = result.goldStakeVault;
    retrievalGuardList = result.retrievalGuardList;
    goldVault = result.goldVault;

    await goldStakeVault.setFeeDistributor(feeDistributor.address);
  });
  describe("Deployment", function () {
    it("should set the right owner", async function () {
      expect(await goldStakeVault.owner()).to.equal(owner.address);
    });
    it("should set the right Gold token address", async function () {
      expect(await goldStakeVault.GoldToken()).to.equal(goldToken.address);
    });
    it("should set the right GBAR token address", async function () {
      expect(await goldStakeVault.GbarToken()).to.equal(gbarToken.address);
    });
    it("should set the right fee distributor address", async function () {
      expect(await goldStakeVault.FeeDistributor()).to.equal(feeDistributor.address);
    });
    it("should have zero total stakers", async function () {
      expect(await goldStakeVault.totalStakers()).to.equal(0);
    });
    it("should have zero total staked", async function () {
      expect(await goldStakeVault.totalSupply()).to.equal(0);
    });
  });
  describe("Staking", function () {
    before(async function () {
      await goldToken.mint(alice.address, 5000);
    });
    it("should revert if amount is zero", async () => {
      await expect(
        goldStakeVault.connect(alice).stake(0)
      ).to.be.rejectedWith("AmountCannotBeZero()");
    });
    it("should revert if amount exceeds sender's balance", async () => {
      await expect(
        goldStakeVault.connect(alice).stake(5001)
      ).to.be.rejectedWith("InsufficientBalance()");
    });
    it("should revert if amount exceeds sender's allowance", async () => {
      await expect(
        goldStakeVault.connect(alice).stake(5)
      ).to.be.rejectedWith("AmountExceedsAllowance()");
    });
    it("should increase total supply and staker's balance if stake amount is valid", async () => {
      // Approve an allowance of 1000 tokens to the contract instance
      await goldToken.connect(alice).approve(goldStakeVault.address, 1000);
      // Stake 500 tokens
      await goldStakeVault.connect(alice).stake(500);
      // Check the total supply and sender's balance
      const totalSupply = await goldStakeVault.totalSupply();
      const stakeBalance = await goldStakeVault.balanceOf(alice.address);
      const tokenBalance = await goldToken.balanceOf(alice.address);
      const totalStakers = await goldStakeVault.totalStakers();
      expect(totalSupply).to.equal(500);
      expect(stakeBalance).to.equal(500);
      expect(tokenBalance).to.equal(4500);
      expect(totalStakers).to.equal(1);
    });
    it("should emit Staked event", async () => {
      await expect(goldStakeVault.connect(alice).stake(500))
        .to.emit(goldStakeVault, "Staked")
        .withArgs(alice.address, 500);
    });
    it("should stake multiple times", async () => {
      // Approve an allowance of 1000 tokens to the contract instance
      await goldToken.connect(alice).approve(goldStakeVault.address, 1000);
      // Stake 500 tokens
      await goldStakeVault.connect(alice).stake(500);
      // fast-forward 60 seconds
      await ethers.provider.send("evm_increaseTime", [60]);
      // Stake 500 tokens
      await goldStakeVault.connect(alice).stake(500);
      const entry = await goldStakeVault.connect(alice).getStakeEntry();
      // startDate should be the timestamp of the first stake
      expect(entry.lastUpdated).to.be.gt(entry.startDate);

      // Check the total supply and sender's balance
      const totalSupply = await goldStakeVault.totalSupply();
      const stakeBalance = await goldStakeVault.balanceOf(alice.address);
      const tokenBalance = await goldToken.balanceOf(alice.address);
      const totalStakers = await goldStakeVault.totalStakers();
      expect(totalSupply).to.equal(2000);
      expect(stakeBalance).to.equal(2000);
      expect(tokenBalance).to.equal(3000);
      expect(totalStakers).to.equal(1);
    });
  });
  describe("Mint Stake", function () {
    before(async function() {
      const totalSupply = await goldStakeVault.totalSupply();
      expect(totalSupply).to.equal(2000); // previous stakes
    });
    it("should revert if amount is zero", async () => {
      await expect(
        goldToken.stakeMint(alice.address, 0)
      ).to.be.rejectedWith("AmountCannotBeZero()");
    });
    it("should revert if called by non owner", async () => {
      await expect(
        goldToken.connect(alice).stakeMint(alice.address, 500)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("should revert if called by non gold contract", async () => {
      await expect(
        goldStakeVault.mintStake(500, alice.address)
      ).to.be.rejectedWith("NotGoldToken()");
    });
    it("should revert if minted to address(0)", async () => {
      await expect(
        goldToken.stakeMint(ethers.constants.AddressZero, 500)
      ).to.be.rejectedWith("MintToAddressZero()");
    });
    it("should mint stake to the given address", async () => {
      await goldToken.stakeMint(bob.address, 500);

      // Check if GBAR is minted correctly
      const oracleValues = await goldPriceOracle.getGoldGbarConversion(500);
      const gbarBalance = await gbarToken.totalSupply();
      expect(gbarBalance).to.equal(oracleValues[2]);

      const stakeBalance = await goldStakeVault.balanceOf(bob.address);
      const totalSupply = await goldStakeVault.totalSupply();
      const totalStakers = await goldStakeVault.totalStakers();

      expect(stakeBalance).to.equal(500);
      expect(totalSupply).to.equal(2500);
      expect(totalStakers).to.equal(2); // alice and bob
    });
  });
  describe("Withdraw gold from stake entry", function () {
    it("should check current stake balances of alice and bob", async () => {
      const stakeBalanceAlice = await goldStakeVault.balanceOf(alice.address)
      expect(stakeBalanceAlice).to.equal(2000);
      const stakeBalanceBob = await goldStakeVault.balanceOf(bob.address)
      expect(stakeBalanceBob).to.equal(500);
    });
    it("should revert if entry is not valid", async () => {
      await expect(
        goldStakeVault.connect(charlie).withdrawGold(0)
      ).to.be.rejectedWith(`EntryDoesNotExist("${charlie.address}")`);
    });
    it("should revert if withdraw is more than staked balance", async () => {
      await expect(
        goldStakeVault.connect(alice).withdrawGold(2001)
      ).to.be.rejectedWith("CannotWithdrawMoreThanStaked(2000)");
    });
    it("should decrease total stakers if staker withdraws all", async () => {
      await goldStakeVault.connect(alice).withdrawGold(2000);
      const totalStakers = await goldStakeVault.totalStakers();
      expect(totalStakers).to.equal(1);

      // total stake should be 500
      const totalSupply = await goldStakeVault.totalSupply();
      expect(totalSupply).to.equal(500);

      // tokens should be transferred back to alice
      const tokenBalance = await goldToken.balanceOf(alice.address);
      expect(tokenBalance).to.equal(5000); // previous balance + 2000
    });
    it("should revert if withdrawn twice", async () => {
      await expect(
        goldStakeVault.connect(alice).withdrawGold(1)
      ).to.be.rejectedWith(`EntryDoesNotExist("${alice.address}")`);
    });
  });
  describe("Get fees from transactions", function () {
    it("should simulate 500 token transactions between four users", async () => {
      await makeGbarTransactions(500);
    });
  });
  describe("Distribute fees to stake vault", function () {
    it("should check current stake balances of alice and bob", async () => {
      const stakeBalanceAlice = await goldStakeVault.balanceOf(alice.address)
      expect(stakeBalanceAlice).to.equal(0);
      await goldStakeVault.connect(bob).withdrawGold(450)
      const stakeBalanceBob = await goldStakeVault.balanceOf(bob.address)
      expect(stakeBalanceBob).to.equal(50);
    });
    it("should stake for alice and charlie", async () => {
      // Approve an allowance of 1000 tokens to the contract instance
      await goldToken.connect(alice).approve(goldStakeVault.address, 35);
      await goldToken.mint(charlie.address, 10);
      await goldToken.connect(charlie).approve(goldStakeVault.address, 10);
      // Stake 3500 tokens
      await goldStakeVault.connect(alice).stake(35);
      await goldStakeVault.connect(charlie).stake(10);

      // Check the total supply and sender's balance
      const totalSupply = await goldStakeVault.totalSupply();
      const totalStakers = await goldStakeVault.totalStakers();
      expect(totalSupply).to.equal(95);
      expect(totalStakers).to.equal(3);
    });
    it("should distribute GBAR rewards to stakers", async () => {
      const feeDistributorBalance = await gbarToken.balanceOf(feeDistributor.address);
      expect(feeDistributorBalance).to.be.gt(ethers.utils.parseUnits("0", 6));

      // Distribute is not yet open
      const periodFinished = await feeDistributor.periodFinish();
      const currentBlocktime = await ethers.provider.getBlock("latest").then(block => block.timestamp);
      expect(periodFinished).to.be.gt(currentBlocktime);
      await expect(
        feeDistributor.connect(alice).setPayoutValues()
      ).to.be.rejectedWith(`DistributionPeriodNotFinished(${periodFinished})`);

      await ethers.provider.send("evm_increaseTime", [86400]); // add 1 day

      await updateGoldPriceOracle();

      // get distributor balance before distribution
      const collectedFee = await gbarToken.balanceOf(feeDistributor.address);
      await feeDistributor.connect(alice).setPayoutValues();
      await feeDistributor.connect(alice).distributeRewards();

      // calculate if fees are distributed correctly
      const totalSupply = await goldStakeVault.totalSupply();
      const oracleResult = await goldPriceOracle.getGoldGbarConversion(totalSupply);

      // 50% of collected fees are distributed, other 50% is for company growth
      const maxRewardsToDistribute = (collectedFee * 50e6 / 100e6);
      const interestRate = await feeDistributor.INTEREST_RATE();
      // daily interest to distribute
      let interest: any = (oracleResult[1] * interestRate / 100e6);

      if (interest > maxRewardsToDistribute) {
        interest = maxRewardsToDistribute;
      }
      interest = Math.floor(interest);
      const vaultBalance = await gbarToken.balanceOf(goldStakeVault.address);
      expect(vaultBalance).to.equal(ethers.utils.parseUnits(interest.toString(), 0));
      const blockTime = await ethers.provider.getBlock("latest").then(block => block.timestamp);
      expect(await feeDistributor.periodFinish()).to.gt(blockTime);
      expect(await feeDistributor.distributeOpen()).to.equal(false);
    });
    it("should revert if distribute rewards is not open", async () => {
      await ethers.provider.send("evm_increaseTime", [86400]); // add 1 day
      await expect(
        feeDistributor.connect(alice).distributeRewards()
      ).to.be.rejectedWith(`DistributionNotOpen()`);
    });
    // todo move to fee distributor unit tests
    // it("should revert if setPayoutValues is already called and open", async () => {
    //   await ethers.provider.send("evm_increaseTime", [86400]); // add 1 day
    //   await updateGoldPriceOracle();
    //   await feeDistributor.connect(alice).setPayoutValues();
    //   await expect(
    //     feeDistributor.connect(alice).setPayoutValues()
    //   ).to.be.rejectedWith(`DistributionAlreadyOpen()`);
    // });
  });
  describe("Rewards and earnings", function () {
    before("Distribute rewards for 30 days", async () => {
      const feeDistributorBalance = await gbarToken.balanceOf(feeDistributor.address);
      console.log(`total GBAR rewards in distributor ${feeDistributorBalance.toString()}`); // total rewards distributed

      for(let i= 1; i <= 365; i++) {
        await ethers.provider.send("evm_increaseTime", [86400]); // add 1 day
        await updateGoldPriceOracle();
        await feeDistributor.connect(alice).setPayoutValues();
        await feeDistributor.connect(alice).distributeRewards();
      }
      const vaultBalance = await gbarToken.balanceOf(goldStakeVault.address);
      console.log(`total GBAR rewards in vault ${vaultBalance.toString()}`); // total rewards distributed

      const goldPrice = await goldPriceOracle.getLatestPrice();
      console.log(`Gold Price in USD ${goldPrice.toString()}`); // total rewards distributed

      const totalStaked = await goldStakeVault.totalSupply();
      const oracleResult = await goldPriceOracle.getGoldGbarConversion(totalStaked);
      console.log(`total staked ${totalStaked.toString()}`); // total staked
      console.log(`Gold Price in Gram ${oracleResult[0].toString()}`);

      console.log(`Gold Value ${oracleResult[1].toString()}`);
      console.log(`GBAR Value ${oracleResult[2].toString()}`); // GBAR Value staked

      const rewardRate = await goldStakeVault.rewardRate(); // 1010971
      console.log(`Reward rate ${rewardRate.toString()}`);

      const lastUpdateTime = await goldStakeVault.lastUpdateTime();
      const currentBlockTimestamp = await ethers.provider.getBlock("latest").then(block => block.timestamp);
      console.log(`Last update time ${lastUpdateTime.toString()}`);
      console.log(`Current block time ${currentBlockTimestamp.toString()}`);

      // rewardPerToken
      const rewardPerTokenCalc = ((((currentBlockTimestamp - lastUpdateTime) * (rewardRate / 1e6))) / totalStaked)
      console.log(`Reward per token calculated ${rewardPerTokenCalc.toString()}`); // GBAR Value staked
      const rewardPerTokenStored = await goldStakeVault.rewardPerTokenStored();
      console.log(`Reward per token stored ${rewardPerTokenStored.toString()}`);

      const rewardPerToken = await goldStakeVault.rewardPerToken();
      console.log(`Reward per token ${rewardPerToken.toString()}`);
    });
    it("should get earned for alice", async () => {
      const gbarBalanceBefore = await gbarToken.balanceOf(alice.address);
      console.log(`GBAR balance before ${gbarBalanceBefore.toString()}`);

      const staked = await goldStakeVault.balanceOf(alice.address);
      console.log(`Staked ${staked.toString()}`);

      const earned = await goldStakeVault.earned(alice.address);
      console.log(`Earned ${earned.toString()}`);
      console.log(`Earned ${ethers.utils.formatUnits(earned, 6)}`);
      expect(earned).to.be.gt(0);

      const reward = await goldStakeVault.Rewards(alice.address);
      console.log(`reward ${reward.toString()}`);

      const rewardPerTokenPaid = await goldStakeVault.UserRewardPerTokenPaid(alice.address);
      console.log(`rewardPerTokenPaid ${rewardPerTokenPaid.toString()}`);

      // // claim rewards
      // await goldStakeVault.connect(alice).claimRewards();
      //
      // const gbarBalanceAfter = await gbarToken.balanceOf(alice.address);
      // console.log(`GBAR balance after ${gbarBalanceAfter.toString()}`);

      // difference between before and after should be equal to earned
      // expect(gbarBalanceAfter.sub(gbarBalanceBefore)).to.equal(earned);
      // expect(gbarBalanceAfter).to.be.gt(gbarBalanceBefore);
    });
    it("should get earned for bob", async () => {
      const staked = await goldStakeVault.balanceOf(bob.address);
      console.log(`Staked ${staked.toString()}`);

      const earned = await goldStakeVault.earned(bob.address);
      console.log(`Earned ${earned.toString()}`);

      expect(earned).to.be.gt(0);
      const reward = await goldStakeVault.Rewards(bob.address);
      console.log(`reward ${reward.toString()}`);

      const rewardPerTokenPaid = await goldStakeVault.UserRewardPerTokenPaid(bob.address);
      console.log(`rewardPerTokenPaid ${rewardPerTokenPaid.toString()}`);
    });
    it("should get earned for charlie", async () => {
      const staked = await goldStakeVault.balanceOf(charlie.address);
      console.log(`Staked ${staked.toString()}`);

      const earned = await goldStakeVault.earned(charlie.address);
      console.log(`Earned ${earned.toString()}`);

      expect(earned).to.be.gt(0);
      const reward = await goldStakeVault.Rewards(charlie.address);
      console.log(`reward ${reward.toString()}`);

      const rewardPerTokenPaid = await goldStakeVault.UserRewardPerTokenPaid(bob.address);
      console.log(`rewardPerTokenPaid ${rewardPerTokenPaid.toString()}`);
    });
  });
  describe("Owner", function () {
    it("should set the right fee distributor address", async function () {
      await goldStakeVault.setFeeDistributor(feeDistributor.address);
      expect(await goldStakeVault.FeeDistributor()).to.equal(feeDistributor.address);
    });
    it("should revert if fee distributor address is zero", async () => {
      await expect(
        goldStakeVault.setFeeDistributor(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero()");
    });
    it("should revert if called by non-owner", async () => {
      await expect(
        goldStakeVault.connect(alice).setFeeDistributor(feeDistributor.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("should recover ERC20 GBAR token", async () => {
      const amount = ethers.utils.parseUnits("1000", 6);
      await mintGbar(goldStakeVault, amount);
      await goldStakeVault.recoverERC20(gbarToken.address, amount);
      expect(await gbarToken.balanceOf(owner.address)).to.equal(amount);
    });
    it("should revert if called by non-owner", async () => {
      await expect(
        goldStakeVault.connect(alice).recoverERC20(gbarToken.address, 1000)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("should revert if recover token is stake token", async () => {
      await expect(
        goldStakeVault.recoverERC20(goldToken.address, 1000)
      ).to.be.rejectedWith("CannotRecoverStakeToken()");
    });
  });
});