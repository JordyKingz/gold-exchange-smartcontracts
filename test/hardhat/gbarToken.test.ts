import {ethers, network, upgrades} from "hardhat";
import { expect } from "chai";
import "@nomicfoundation/hardhat-chai-matchers";
import { FeeProvider } from "../../typechain-types";
import {deployAllContracts, deployContract, upgradeContract} from "../../scripts/utils/helpers";

let goldPriceOracle: any;
let feeProvider: any;
let goldToken: any;
let gbarToken: any;
let gbarVault: any;
let feeDistributor: any;
let goldStakeVault: any;

let gbarTokenV2: any;
let owner: any;
let alice: any;
let bob: any;
let charlie: any;
let dave: any;
let company: any;

let retrievalGuardList: string[] = [];

describe("GBAR token contract", function () {
  beforeEach(async function () {
    [
      owner,
      alice,
      bob,
      charlie,
      dave,
      company,
    ] = await ethers.getSigners();
    const result = await deployAllContracts(owner, charlie, dave, company);
    goldPriceOracle = result.goldPriceOracle;
    feeProvider = result.feeProvider;
    goldToken = result.goldToken;
    gbarToken = result.gbarToken;
    gbarVault = result.gbarVault;
    feeDistributor = result.feeDistributor;
    goldStakeVault = result.goldStakeVault;
    retrievalGuardList = result.retrievalGuardList;

  });
  describe("Deployment", function () {
    it("Should set the right decimals", async function () {
      expect(await gbarToken.decimals()).to.equal(6);
    });
    it("Should set the right name", async function () {
      expect(await gbarToken.name()).to.equal("GBAR");
    });
    it("Should set the right symbol", async function () {
      expect(await gbarToken.symbol()).to.equal("GBAR");
    });
    it("Should set the right owner", async function () {
      expect(await gbarToken.owner()).to.equal(owner.address);
    });
    it("Should set the right fee provider", async function () {
      expect(await gbarToken.FeeProvider()).to.equal(feeProvider.address);
    });
    it("Should set the right gold token", async function () {
      expect(await gbarToken.GoldToken()).to.equal(goldToken.address);
    });
    it("Should set the right number of required signatures", async function () {
      expect(await gbarToken.numConfirmationsRequired()).to.equal(retrievalGuardList.length);
    });
    it("Should set the right fee distributor", async function () {
      expect(await gbarToken.FeeDistributor()).to.equal(feeDistributor.address);
    });
    it("Should set the right gbar vault", async function () {
      expect(await gbarToken.GbarVault()).to.equal(gbarVault.address);
    });
    it("Should have zero retrieval requests", async function () {
      expect(await gbarToken.getRetrievalRequestCount()).to.equal(0);
    });
    it("Should have three retrieval guards", async function () {
      expect(await gbarToken.getRetrievalRetrievalGuardsCount()).to.equal(retrievalGuardList.length);
    });
    it("Should revert, retrieval request does not exists", async function () {
      await expect(
        gbarToken.getRetrievalRequest(1)
      ).to.be.rejectedWith("RetrievalRequestDoesNotExist");
    });
  });
  describe("Owner functions", function () {
    it("Should mint tokens to GBAR_VAULT", async function () {
      const mintAmount = ethers.utils.parseUnits("1000", 6);
      await gbarToken.mint(mintAmount);
      expect(await gbarToken.balanceOf(gbarVault.address)).to.equal(mintAmount);
    });
    it("Should be able to set new owner", async function () {
      await gbarToken.transferOwnership(alice.address);
      expect(await gbarToken.owner()).to.equal(alice.address);
    });
    it("Should not be able to set new owner from non-owner", async function () {
      await expect(
        gbarToken.connect(alice).transferOwnership(alice.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert mint tokens amount is zero", async function () {
      await expect(
        gbarToken.mint(0)
      ).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should add address to blacklist", async function () {
      await mintTokens(alice.address, 100);
      expect(await gbarToken.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 6));

      await gbarToken.addBlacklist(alice.address);
      expect(await gbarToken.blacklist(alice.address)).to.be.true;

      await expect(
        gbarToken.connect(alice).transfer(bob.address, ethers.utils.parseUnits("100", 6))
      ).to.be.rejectedWith("BlacklistedTransaction");
    });
    it("Should revert add address to blacklist no owner", async function () {
      await expect(
        gbarToken.connect(alice).addBlacklist(bob.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert add address to blacklist address(0)", async function () {
      await expect(
        gbarToken.addBlacklist(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should remove address from blacklist", async function () {
      await mintTokens(alice.address, 100);
      expect(await gbarToken.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 6));

      await gbarToken.addBlacklist(alice.address);
      expect(await gbarToken.blacklist(alice.address)).to.be.true;

      await expect(
        gbarToken.connect(alice).transfer(bob.address, ethers.utils.parseUnits("100", 6))
      ).to.be.rejectedWith("BlacklistedTransaction");

      await gbarToken.removeBlacklist(alice.address);
      expect(await gbarToken.blacklist(alice.address)).to.be.false;

      await gbarToken.connect(alice).transfer(bob.address, ethers.utils.parseUnits("100", 6));
      expect(await gbarToken.balanceOf(alice.address)).to.equal(0);
      expect(await gbarToken.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("99", 6));
    });
    it("Should revert remove address from blacklist no owner", async function () {
      await gbarToken.addBlacklist(alice.address);
      expect(await gbarToken.blacklist(alice.address)).to.be.true;

      await expect(
        gbarToken.connect(alice).removeBlacklist(bob.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert remove address from blacklist address(0)", async function () {
      await expect(
        gbarToken.removeBlacklist(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should set new FEE_DISTRIBUTOR", async function () {
      const upgradedContract = await upgradeContract("FeeDistributor", feeDistributor.address);

      await gbarToken.setFeeDistributor(upgradedContract.address);
      expect(await gbarToken.FeeDistributor()).to.equal(upgradedContract.address);
    });
    it("Should revert set new FEE_DISTRIBUTOR no owner", async function () {
      const upgradedContract = await upgradeContract("FeeDistributor", feeDistributor.address);

      await expect(
        gbarToken.connect(alice).setFeeDistributor(upgradedContract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new FEE_DISTRIBUTOR address(0)", async function () {
      await expect(
        gbarToken.setFeeDistributor(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should set new GOLD_CONTRACT", async function () {
      const upgradedContract = await upgradeContract("GOLD", goldToken.address);

      await gbarToken.setGoldContract(upgradedContract.address);
      expect(await gbarToken.GoldToken()).to.equal(upgradedContract.address);
    });
    it("Should revert set new GOLD_CONTRACT no owner", async function () {
      const upgradedContract = await upgradeContract("GOLD", goldToken.address);

      await expect(
        gbarToken.connect(alice).setGoldContract(upgradedContract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new GOLD_CONTRACT address(0)", async function () {
      await expect(
        gbarToken.setGoldContract(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should set new GBAR_VAULT", async function () {
      const upgradedContract = await upgradeContract("GBARVault", gbarVault.address);

      await gbarToken.setGBARVault(upgradedContract.address);
      expect(await gbarToken.GbarVault()).to.equal(upgradedContract.address);
    });
    it("Should revert set new GBAR_VAULT no owner", async function () {
      const upgradedContract = await upgradeContract("GBARVault", gbarVault.address);

      await expect(
        gbarToken.connect(alice).setGBARVault(upgradedContract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new GBAR_VAULT address(0)", async function () {
      await expect(
        gbarToken.setGBARVault(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should set new FEE_PROVIDER", async function () {
      const contract = await deployContract("FeeProvider");
      await gbarToken.setFeeProvider(contract.address);
      expect(await gbarToken.FeeProvider()).to.equal(contract.address);
    });
    it("Should revert set new FEE_PROVIDER no owner", async function () {
      const contract = await deployContract("FeeProvider");

      await expect(
        gbarToken.connect(alice).setFeeProvider(contract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new FEE_PROVIDER address(0)", async function () {
      await expect(
        gbarToken.setFeeProvider(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should add address to fee exclusion", async function () {
      await gbarToken.addFeeExclusion(alice.address);
      expect(await gbarToken.excludedFromFee(alice.address)).to.be.true;

      await mintTokens(alice.address, 100);

      await gbarToken.connect(alice).transfer(bob.address, 100);
      expect(await gbarToken.balanceOf(bob.address)).to.equal(100);
    });
    it("Should revert add address to fee exclusion no owner", async function () {
      await expect(
        gbarToken.connect(alice).addFeeExclusion(alice.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert add address to fee exclusion address(0)", async function () {
      await expect(
        gbarToken.addFeeExclusion(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should remove address from fee exclusion", async function () {
      await gbarToken.removeFeeExclusion(alice.address);
      expect(await gbarToken.excludedFromFee(alice.address)).to.be.false;

      await mintTokens(alice.address, 100);

      await gbarToken.connect(alice).transfer(bob.address, 100);
      expect(await gbarToken.balanceOf(bob.address)).to.equal(99); // 1% fee
    });
    it("Should revert remove address from fee exclusion no owner", async function () {
      await gbarToken.addFeeExclusion(alice.address);
      expect(await gbarToken.excludedFromFee(alice.address)).to.be.true;

      await expect(
        gbarToken.connect(alice).removeFeeExclusion(alice.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert remove address from fee exclusion address(0)", async function () {
      await expect(
        gbarToken.removeFeeExclusion(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should burn tokens", async function () {
      await mintTokens(alice.address, 100);
      expect(await gbarToken.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 6));
      await gbarToken.addBlacklist (alice.address);
      await gbarToken.burn(alice.address, ethers.utils.parseUnits("100", 6));
      expect(await gbarToken.balanceOf(alice.address)).to.equal(0);
    });
    it("Should revert burn tokens no owner", async function () {
      await expect(
        gbarToken.connect(bob).burn(alice.address, 100)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert burn tokens amount zero", async function () {
      await expect(
        gbarToken.burn(alice.address, 0)
      ).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should revert burn tokens address not blacklisted", async function () {
      await expect(
        gbarToken.burn(alice.address, 100)
      ).to.be.rejectedWith("AddressNotBlacklisted");
    });
  });
  describe("Minting", function () {
    describe("GBAR Mint", function () {
      it("Should mint tokens", async function () {
        await gbarToken.mint(ethers.utils.parseUnits("100", 6));
        expect(await gbarToken.balanceOf(gbarVault.address)).to.equal(ethers.utils.parseUnits("100", 6));
      });
      it("Should revert mint tokens amount 0", async function () {
        await expect(
          gbarToken.mint(0)
        ).to.be.rejectedWith("AmountCannotBeZero");
      });
      it("Should revert mint tokens no owner", async function () {
        await expect(
          gbarToken.connect(alice).mint(100)
        ).to.be.rejectedWith("Ownable: caller is not the owner");
      });
    });
    describe("Gold Value Mint", function () {
      it("Should mint gbar based on gold value, called by gold contract", async function () {
        await goldToken.setGbarToken(gbarToken.address);

        const goldAmountInGrams = 100;
        const oracleResult = await goldPriceOracle.getGoldGbarConversion(goldAmountInGrams);

        await goldToken.mintGoldAndGbar(alice.address, goldAmountInGrams);
        expect(await goldToken.balanceOf(alice.address)).to.equal(goldAmountInGrams);
        expect(await gbarToken.balanceOf(gbarVault.address)).to.equal(oracleResult[2]);
      });
      it("Should revert mint gbar based on gold value, called by non gold contract", async function () {
        await expect(
          gbarToken.goldValueMint(ethers.utils.parseUnits("100", 6))
        ).to.be.rejectedWith("NotTheGoldContract");
      });
      it("Should revert mint gbar based on gold value, gbar not set in gold contract", async function () {
        await expect(
          goldToken.mintGoldAndGbar(alice.address, 100)
      ).to.be.rejectedWith("GBARTokenNotSet");
      });
    });
  });
  describe("Transfers", function () {
    beforeEach(async function () {
      await mintTokens(alice.address, 100000);
      await mintTokens(bob.address, 100000);
      await mintTokens(charlie.address, 100000);
      await mintTokens(dave.address, 10000);
    });
    // test transfer & transferFrom
    describe("Get Fee from transfers", function () {
      beforeEach(async function () {
        const amountOne = ethers.utils.parseUnits("100", 6);
        // 1 fee per transfer
        for(let i = 0; i < 100; i++) {
          await gbarToken.connect(alice).transfer(bob.address, amountOne);
          await gbarToken.connect(bob).transfer(charlie.address, amountOne);
          await gbarToken.connect(charlie).transfer(dave.address, amountOne);
          await gbarToken.connect(dave).transfer(alice.address, amountOne);
        }
        const amountTwo = ethers.utils.parseUnits("10000", 6);
        // 1.24 fee per transfer
        for(let i = 0; i < 5; i++) {
          await gbarToken.connect(alice).transfer(bob.address, amountTwo);
          await gbarToken.connect(bob).transfer(charlie.address, amountTwo);
          await gbarToken.connect(charlie).transfer(dave.address, amountTwo);
          await gbarToken.connect(dave).transfer(alice.address, amountTwo);
        }
        const amountThree = ethers.utils.parseUnits("1000", 6);
        // 1.024 fee per transfer
        for(let i = 0; i < 10; i++) {
          await gbarToken.connect(alice).transfer(bob.address, amountThree);
          await gbarToken.connect(bob).transfer(charlie.address, amountThree);
          await gbarToken.connect(charlie).transfer(dave.address, amountThree);
          await gbarToken.connect(dave).transfer(alice.address, amountThree);
        }
      });
      it("Should get fee from transfers", async function () {
        const feeFromTxOne = ethers.utils.parseUnits("400", 6);
        const feeFromTxTwo = ethers.utils.parseUnits("24.8", 6);
        const feeFromTxThree = ethers.utils.parseUnits("40.96", 6);

        const totalFee = feeFromTxOne.add(feeFromTxTwo).add(feeFromTxThree);
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(totalFee);
      });
    });
    describe("Get fee from transferFrom", function () {
      beforeEach(async function () {
        const amount = ethers.utils.parseUnits("100000", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await gbarToken.connect(bob).approve(charlie.address, amount);
        await gbarToken.connect(charlie).approve(dave.address, amount);
        await gbarToken.connect(dave).approve(alice.address, amount);


        const amountOne = ethers.utils.parseUnits("100", 6);
        // 1 fee per transfer
        for(let i = 0; i < 100; i++) {
          await gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amountOne);
          await gbarToken.connect(charlie).transferFrom(bob.address, dave.address, amountOne);
          await gbarToken.connect(dave).transferFrom(charlie.address, alice.address, amountOne);
          await gbarToken.connect(alice).transferFrom(dave.address, bob.address, amountOne);
        }
        const amountTwo = ethers.utils.parseUnits("10000", 6);
        // 1.24 fee per transfer
        for(let i = 0; i < 5; i++) {
          await gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amountTwo);
          await gbarToken.connect(charlie).transferFrom(bob.address, dave.address, amountTwo);
          await gbarToken.connect(dave).transferFrom(charlie.address, alice.address, amountTwo);
          await gbarToken.connect(alice).transferFrom(dave.address, bob.address, amountTwo);
        }
        const amountThree = ethers.utils.parseUnits("1000", 6);
        // 1.024 fee per transfer
        for(let i = 0; i < 10; i++) {
          await gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amountThree);
          await gbarToken.connect(charlie).transferFrom(bob.address, dave.address, amountThree);
          await gbarToken.connect(dave).transferFrom(charlie.address, alice.address, amountThree);
          await gbarToken.connect(alice).transferFrom(dave.address, bob.address, amountThree);
        }
      });
      it("Should get fee transferFrom", async function () {
        const feeFromTxOne = ethers.utils.parseUnits("400", 6);
        const feeFromTxTwo = ethers.utils.parseUnits("24.8", 6);
        const feeFromTxThree = ethers.utils.parseUnits("40.96", 6);

        const totalFee = feeFromTxOne.add(feeFromTxTwo).add(feeFromTxThree);
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(totalFee);
      });
    });
    describe("Should be excluded from fee", function () {
      beforeEach(async function () {
        await gbarToken.addFeeExclusion(alice.address);
      });
      it("Should transfer without fee, sender excluded", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).transfer(bob.address, amount);
        // beforeEach mints 100000 GBAR to alice, bob, charlie, dave
        expect(await gbarToken.balanceOf(bob.address)).to.equal(amount.add(ethers.utils.parseUnits("100000", 6)));
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(0);
      });
      it("Should transfer without fee, receiver excluded", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(bob).transfer(alice.address, amount);
        // beforeEach mints 100000 GBAR to alice, bob, charlie, dave
        expect(await gbarToken.balanceOf(alice.address)).to.equal(amount.add(ethers.utils.parseUnits("100000", 6)));
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(0);
      });
      it("Should transfer from without fee, sender excluded", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amount);
        // beforeEach mints 100000 GBAR to alice, bob, charlie, dave
        expect(await gbarToken.balanceOf(charlie.address)).to.equal(amount.add(ethers.utils.parseUnits("100000", 6)));
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(0);
      });
      it("Should transferFrom without fee, receiver excluded", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amount);
        // beforeEach mints 100000 GBAR to alice, bob, charlie, dave
        expect(await gbarToken.balanceOf(charlie.address)).to.equal(amount.add(ethers.utils.parseUnits("100000", 6)));
        expect(await gbarToken.balanceOf(feeDistributor.address)).to.equal(0);
      });
    });
    describe("Transfers should revert", function () {
      beforeEach(async function () {
        await gbarToken.addBlacklist(charlie.address);
      });
      it("Should revert transfer, not enough balance", async function () {
        const amount = ethers.utils.parseUnits("1000000", 6);
        await expect(gbarToken.connect(alice).transfer(bob.address, amount)).to.be.rejectedWith("ERC20: transfer amount exceeds balance");
      });
      it("Should revert transfer, sent to address(0)", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await expect(gbarToken.connect(alice).transfer(ethers.constants.AddressZero, amount)).to.be.rejectedWith("AddressCannotBeZero");
      });
      it("Should revert transfer, amount is zero", async function () {
        await expect(gbarToken.connect(alice).transfer(bob.address, 0)).to.be.rejectedWith("AmountCannotBeZero");
      });
      it("Should revert transfer, blacklisted sender", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await expect(gbarToken.connect(charlie).transfer(bob.address, amount)).to.be.rejectedWith("BlacklistedTransaction");
      });
      it("Should revert transfer, blacklisted receiver", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await expect(gbarToken.transfer(charlie.address, amount)).to.be.rejectedWith("BlacklistedTransaction");
      });
      it("Should revert transferFrom, not enough balance", async function () {
        const amount = ethers.utils.parseUnits("100001", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(alice.address, dave.address, amount)).to.be.rejectedWith("ERC20: transfer amount exceeds balance");
      });
      it("Should revert transferFrom, sent to address(0)", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(alice.address, ethers.constants.AddressZero, amount)).to.be.rejectedWith("AddressCannotBeZero");
      });
      it("Should revert transferFrom, amount is zero", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(alice.address, charlie.address, 0)).to.be.rejectedWith("AmountCannotBeZero");
      });
      it("Should revert transferFrom, blacklisted sender", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(charlie).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(charlie.address, alice.address, amount)).to.be.rejectedWith("BlacklistedTransaction");
      });
      it("Should revert transferFrom, blacklisted receiver", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(alice.address, charlie.address, amount)).to.be.rejectedWith("BlacklistedTransaction");
      });
      it("Should revert transferFrom, not enough allowance", async function () {
        const amount = ethers.utils.parseUnits("100", 6);
        await gbarToken.connect(alice).approve(bob.address, amount);
        await expect(gbarToken.connect(bob).transferFrom(alice.address, dave.address, amount.add(1))).to.be.rejectedWith("ERC20: insufficient allowance");
      });
    });
  });
  describe("Stabilize revert", function () {
    it("Should revert stabilize time not passed", async function () {
      await expect(gbarToken.stabilize()).to.be.rejectedWith("StabilizeTimestampNoPassed");
    });
  });
  describe("Stabilize GBAR increment block timestamp", async function () {
    // stabilization is possible after 28 days.
    // forward time by 28 days
    beforeEach(async function () {
      await network.provider.send("evm_increaseTime", [28 * 24 * 60 * 60]);
      await network.provider.send("evm_mine");

      await ethers.provider.getBlock("latest");
    });
    it("Sould revert, no vault balance to stabilize", async function () {
      await goldToken.mint(owner.address, 100);
      await expect(gbarToken.stabilize()).to.be.rejectedWith("StabilizeNotPossible");
    });
    it("Sould revert, no gold balance", async function () {
      await mintTokens(gbarVault.address, 100);
      await expect(gbarToken.stabilize()).to.be.rejectedWith("StabilizeNotPossible");
    });
    describe("Stabilize GBAR", async function () {
      it("Should be 85% GBAR circulation based on 1000 tokens gold", async function () {
        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        const oracleResult = await goldPriceOracle.getGoldGbarConversion(1000);
        // mint gbar tokens based on 85% of gold value
        await gbarToken.mint(oracleResult[2]);

        const gbarTotalSupply = await gbarToken.totalSupply();
        const gbarValue = await gbarToken.balanceOf(gbarVault.address);
        const goldPriceInGram = oracleResult[0];
        const totalGoldValue = oracleResult[1];
        // check emitted event
        await expect(gbarToken.stabilize())
          .to.emit(gbarToken, "Stabilized")
          .withArgs(gbarTotalSupply, gbarValue, goldPriceInGram, totalGoldValue);
      });
      it("Should burn GBAR from vault balance, more than allowed", async function () {
        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        const oracleResult = await goldPriceOracle.getGoldGbarConversion(1000);
        // mint gbar tokens based on 85% of gold value
        await gbarToken.mint(oracleResult[2]);

        const totalSupplyBefore = await gbarToken.totalSupply();
        await mintTokens(gbarVault.address, 100);
        const gbarTotalSupplyAfter = await gbarToken.totalSupply();
        await expect(gbarTotalSupplyAfter)
          .to.be.equal(totalSupplyBefore.add(ethers.utils.parseUnits("100", 6)));

        expect(await gbarToken.balanceOf(gbarVault.address))
          .to.be.equal(totalSupplyBefore.add(ethers.utils.parseUnits("100", 6)));

        await gbarToken.stabilize();
        const gbarTotalSupplyAfterStabilize = await gbarToken.totalSupply();
        expect(gbarTotalSupplyAfterStabilize).to.be.equal(totalSupplyBefore);
        // 100 gbar burned from vault
        expect(await gbarToken.balanceOf(gbarVault.address))
          .to.be.equal(totalSupplyBefore);
      });
      it("Should burn whole vault balance", async function () {
        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        const oracleResult = await goldPriceOracle.getGoldGbarConversion(1000);
        // mint gbar tokens based on 85% of gold value
        await gbarToken.mint(oracleResult[2]);
        const vaultBalance = await gbarToken.balanceOf(gbarVault.address);
        await gbarVault.withdrawTo(alice.address, vaultBalance);
        expect(await gbarToken.balanceOf(gbarVault.address)).to.be.equal(0);

        await gbarToken.mint(ethers.utils.parseUnits("500", 6));
        await gbarVault.withdrawTo(alice.address, ethers.utils.parseUnits("50", 6));
        expect(await gbarToken.balanceOf(gbarVault.address)).to.be.equal(ethers.utils.parseUnits("450", 6));

        // we need to burn 500 gbar, but vault has only 450 gbar. So we burn the vault balance, rest is in circulation
        // that we cannot burn
        await gbarToken.stabilize();
        const gbarVaultBalance = await gbarToken.balanceOf(gbarVault.address);
        expect(gbarVaultBalance).to.be.equal(0);
      });
      it("Should mint GBAR, less supply than allowed", async function () {
        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        let oracleResult = await goldPriceOracle.getGoldGbarConversion(1000);
        await gbarToken.mint(oracleResult[2]);
        // total supply & gbar vault should have 85% of gold value
        expect(await gbarToken.totalSupply()).to.be.equal(oracleResult[2]);
        expect(await gbarToken.balanceOf(gbarVault.address)).to.be.equal(oracleResult[2]);

        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        oracleResult = await goldPriceOracle.getGoldGbarConversion(2000);
        // gbar 85% of 2kg gold value
        const gbarTotalSupplyShouldBe = oracleResult[2];
        // should mint 85% of 1kg extra gold value
        await gbarToken.stabilize();
        // total supply should be 85% of 2kg gold value
        expect(await gbarToken.totalSupply()).to.be.equal(gbarTotalSupplyShouldBe);
      });
      it("Should call stabilize twice and revert once", async function () {
        await goldToken.mint(owner.address, 1000); // mint 1kg gold tokens
        let oracleResult = await goldPriceOracle.getGoldGbarConversion(1000);
        await gbarToken.mint(oracleResult[2]);
        await gbarToken.stabilize();

        await expect(gbarToken.stabilize()).to.be.rejectedWith("StabilizeTimestampNoPassed");
      });
    });
  });
  describe("Retrieval guards", function () {
    beforeEach(async function () {
      await mintTokens(alice.address, 100);
      await mintTokens(bob.address, 100);
    });
    it("Should create retrieval request", async function () {
      await gbarToken.createRetrievalRequest(alice.address, ethers.utils.parseUnits("100", 6));
      const request = await gbarToken.getRetrievalRequest(0);
      expect(request[0]).to.equal(alice.address);
      expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
    });
    it("Should revert create retrieval request not retrievalGuard", async function () {
      await expect(
        gbarToken.connect(alice).createRetrievalRequest(bob.address, ethers.utils.parseUnits("100", 6))
      ).to.be.rejectedWith("NotTheRetrievalGuard");
    });
    it("Should revert create retrieval request address(0)", async function () {
      await expect(
        gbarToken.createRetrievalRequest(ethers.constants.AddressZero, ethers.utils.parseUnits("100", 6))
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should revert create retrieval request amount zero", async function () {
      await expect(
        gbarToken.createRetrievalRequest(bob.address, ethers.utils.parseUnits("0", 6))
      ).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should revert, retrieval request does not exists", async function () {
      await expect(
        gbarToken.getRetrievalRequest(1)
      ).to.be.rejectedWith("RetrievalRequestDoesNotExist");
    });
    describe("Retrieval request exists", function () {
      beforeEach(async function () {
        await mintTokens(alice.address, 100);
        await gbarToken.createRetrievalRequest(alice.address, ethers.utils.parseUnits("100", 6));
      });
      it("Should confirm retrieval request", async function () {
        await gbarToken.confirmRetrievalRequest(0);
        const request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(1); // 1 = confirmed
      });
      it("Should revert, double confirm retrieval request", async function () {
        await gbarToken.confirmRetrievalRequest(0);
        const request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(1); // 1 = confirmed

        await expect(
          gbarToken.confirmRetrievalRequest(0)
        ).to.be.rejectedWith("RetrievalRequestAlreadyConfirmed");

      });
      it("Should confirm and execute retrieval request", async function () {
        await gbarToken.confirmRetrievalRequest(0);
        let request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(1); // 1 = confirmed

        await gbarToken.connect(charlie).confirmRetrievalRequest(0);
        request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(2); // 2 = confirmed

        await gbarToken.connect(dave).confirmRetrievalRequest(0);
        request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(3); // 3 = confirmed

        await gbarToken.executeRetrievalRequest(0);
        request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[3]).to.equal(true); // executed = true
        expect(await gbarToken.blacklist(alice.address)).to.be.true;
      });
      it("Should revert confirm and execute retrieval request not enough confirmations", async function () {
        await gbarToken.confirmRetrievalRequest(0);
        let request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(1); // 1 = confirmed

        await gbarToken.connect(charlie).confirmRetrievalRequest(0);
        request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[1]).to.equal(ethers.utils.parseUnits("100", 6));
        expect(request[2]).to.equal(2); // 2 = confirmed

        await expect(gbarToken.executeRetrievalRequest(0)).to.be.rejectedWith("NotEnoughConfirmations");
      });
      it("Should revoke confirmation", async function () {
        await gbarToken.confirmRetrievalRequest(0);
        let request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[2]).to.equal(1); // 1 = confirmed

        await gbarToken.revokeConfirmation(0);
        request = await gbarToken.getRetrievalRequest(0);
        expect(request[0]).to.equal(alice.address);
        expect(request[2]).to.equal(0);
      });
      it("Should revert revoke confirmation not confirmed", async function () {
        await expect(gbarToken.revokeConfirmation(0)).to.be.rejectedWith("RequestNotConfirmed");
      });
    });
  });
  describe("Upgrading", async function () {
    beforeEach("Change V1 state before upgrading", async function () {
      await changeGbarV1State();

      const gbarV2 = await ethers.getContractFactory("GBARV2");
      gbarTokenV2 = await upgrades.upgradeProxy(gbarToken.address, gbarV2);
    });
    it("Should have the new function", async function () {
      const value = await gbarTokenV2.newFunction();
      expect(value.toString()).to.equal('newFunction');
    });
    it("Should have the old state", async function () {
      expect(await gbarTokenV2.FeeProvider()).to.equal(feeProvider.address);
      expect(await gbarTokenV2.GoldToken()).to.equal(goldToken.address);
      expect(await gbarTokenV2.FeeDistributor()).to.equal(feeDistributor.address);
      expect(await gbarTokenV2.GbarVault()).to.equal(gbarVault.address);
    });
    it("Should keep the user balances", async function () {
      // balance state changes in changeGbarV1State
      expect(await gbarTokenV2.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("9989.76", 6));
      expect(await gbarTokenV2.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("1989966", 6));
    });
    it("Should have the retrieval requests", async function () {
      const request = await gbarTokenV2.getRetrievalRequest(0);
      expect(request[0]).to.equal(charlie.address);
      expect(request[1]).to.equal(ethers.utils.parseUnits("1000", 6));
      expect(request[2]).to.equal(0); // 0 = confirmed
      expect(request[3]).to.equal(false); // executed = false
    });
    it("Should have the right address in other contracts", async function () {
      const gbarFeeDistributor = await feeDistributor.GbarToken();
      expect(gbarFeeDistributor).to.equal(gbarTokenV2.address);
    });
    it("Should have taken fee from transfers", async function () {
      // fees generated in changeGbarV1State doTransfers
      expect(await gbarTokenV2.balanceOf(feeDistributor.address)).to.equal(ethers.utils.parseUnits("64.72", 6));
    });
    it("Should revert v2 already initialized", async function () {
      await expect(gbarTokenV2.initialize(
        feeProvider.address,
        goldToken.address,
        goldPriceOracle.address,
        3,
        [alice.address, bob.address]
      )).to.be.rejectedWith("Initializable: contract is already initialized");
    });
    it("Should revert owner not upgrading", async function () {
      const gbarV2Factory = await ethers.getContractFactory("GBARV2");
      await expect(
        upgrades.upgradeProxy(gbarToken.address, gbarV2Factory.connect(alice))
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should confirm retrieval request", async function () {
      await gbarToken.confirmRetrievalRequest(0);
      const request = await gbarToken.getRetrievalRequest(0);
      expect(request[0]).to.equal(charlie.address);
      expect(request[1]).to.equal(ethers.utils.parseUnits("1000", 6));
      expect(request[2]).to.equal(1); // 1 = confirmed
    });
    it("Should be the same contract address as V1", async function () {
      expect(gbarToken.address).to.equal(gbarTokenV2.address);
    });
    it("Should have the same owner", async function () {
      expect(await gbarToken.owner()).to.equal(await gbarTokenV2.owner());
    });
  });

  async function mintTokens(to: string, amount: number) {
    await gbarToken.mint(ethers.utils.parseUnits(`${amount}`, 6));
    await gbarVault.withdrawTo(to, ethers.utils.parseUnits(`${amount}`, 6));
  }

  async function changeGbarV1State() {
    await doTransfers();
    await gbarToken.addBlacklist(dave.address);
    await gbarToken.createRetrievalRequest(charlie.address, ethers.utils.parseUnits("1000", 6));
  }

  async function doTransfers() {
    await mintTokens(alice.address, 1000000);
    await mintTokens(bob.address, 1000000);
    await mintTokens(charlie.address, 1000000);
    await mintTokens(dave.address, 1000000);

    for(let i = 0; i < 10; i++) {
      await gbarToken.connect(alice).transfer(bob.address, ethers.utils.parseUnits("100000", 6));
      await gbarToken.connect(bob).transfer(charlie.address, ethers.utils.parseUnits("1000", 6));
      await gbarToken.connect(charlie).transfer(dave.address, ethers.utils.parseUnits("1000", 6));
      await gbarToken.connect(dave).transfer(alice.address, ethers.utils.parseUnits("1000", 6));

    }
  }
});