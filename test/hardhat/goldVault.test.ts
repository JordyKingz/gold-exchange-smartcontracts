import {ethers, upgrades} from "hardhat";
import {deployAllContracts, upgradeContract} from "../../scripts/utils/helpers";
import {expect} from "chai";

let goldPriceOracle: any;
let feeProvider: any;
let goldToken: any;
let goldVault: any;
let gbarToken: any;
let gbarVault: any;
let feeDistributor: any;
let goldStakeVault: any;

let gbarVaultV2: any;
let owner: any;
let alice: any;
let bob: any;
let charlie: any;
let dave: any;
let company: any;

let retrievalGuardList: string[] = [];

describe("GOLD Vault contract", function () {
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
    goldVault = result.goldVault;
  });
  describe("Deployment", function () {
    it("Should set the correct Gold token address", async function () {
      expect(await goldVault.GoldToken()).to.equal(goldToken.address);
    });
    it("Should revert already initialized", async function () {
      await expect(
        goldVault.initialize(goldToken.address)
      ).to.be.rejectedWith("Initializable: contract is already initialized");
    });
    it("Should have 0 Gold balance", async function () {
      expect(await goldVault.getContractBalance()).to.equal("0");
    });
    it("Should have the right owner", async function () {
      expect(await goldVault.owner()).to.equal(owner.address);
    });
  });
  describe("Owner functions", function () {
    it("Should be able to withdraw", async function () {
      await goldToken.mint(owner.address, 1000);
      await goldToken.transfer(goldVault.address, 1000);
      await goldVault.withdrawTo(alice.address, 1000);
      expect(await goldToken.balanceOf(alice.address)).to.equal(1000);
    });
    it("Should revert withdraw not owner", async function () {
      await expect(
        goldVault.connect(alice).withdrawTo(alice.address, 1000)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert withdraw amount exceeds balance", async function () {
      await expect(
        goldVault.withdrawTo(alice.address, 1000)
      ).to.be.rejectedWith("AmountExceedsBalance");
    });
    it("Should revert withdraw amount is zero", async function () {
      await expect(
        goldVault.withdrawTo(alice.address, "0")
      ).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should revert withdraw to address(0)", async function () {
      await expect(
        goldVault.withdrawTo(ethers.constants.AddressZero, 1000)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should be able to set new owner", async function () {
      await goldVault.transferOwnership(alice.address);
      expect(await goldVault.owner()).to.equal(alice.address);
    });
    it("Should not be able to set new owner from non-owner", async function () {
      await expect(
        goldVault.connect(alice).transferOwnership(alice.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should set new gold token address", async function () {
      const upgradedContract = await upgradeContract("GOLD", goldToken.address);

      await goldVault.setGold(upgradedContract.address);
      expect(await goldVault.GoldToken()).to.equal(upgradedContract.address);
    });
    it("Should revert set new gold token address not owner", async function () {
      const upgradedContract = await upgradeContract("GOLD", goldToken.address);

      await expect(
        goldVault.connect(alice).setGold(upgradedContract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new gold address(0)", async function () {
      await expect(
        goldVault.setGold(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
  });
  describe("Deposit", function () {
    it("Should be able to deposit", async function () {
      await goldToken.mint(alice.address, 1000);
      await goldToken.connect(alice).approve(goldVault.address, 1000);
      await goldVault.connect(alice).deposit(1000);
      expect(await goldVault.getContractBalance()).to.equal(1000);
    });
    it("Should revert not enough allowance", async function () {
      await goldToken.mint(owner.address, 1000);

      await expect(
        goldVault.deposit(1000)
      ).to.be.rejectedWith("AmountExceedsAllowance");
    });
    it("Should revert amount exceeds allowance", async function () {
      await goldToken.mint(owner.address, 1000);

      await goldToken.approve(owner.address, 1000);
      await expect(
        goldVault.deposit(1001)
      ).to.be.rejectedWith("AmountExceedsAllowance");
    });
    it("Should revert not enough balance", async function () {
      await goldToken.approve(goldVault.address, 1000);
      await expect(
        goldVault.deposit(1000)
      ).to.be.rejectedWith("ERC20: transfer amount exceeds balance");
    });
  });
});