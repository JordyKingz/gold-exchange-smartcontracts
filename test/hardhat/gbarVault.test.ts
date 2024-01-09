import {ethers, upgrades} from "hardhat";
import {deployAllContracts, upgradeContract} from "../../scripts/utils/helpers";
import {expect} from "chai";

let goldPriceOracle: any;
let feeProvider: any;
let goldToken: any;
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

describe("GBAR Vault contract", function () {
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
    it("Should set the correct GBAR token address", async function () {
      expect(await gbarVault.GbarToken()).to.equal(gbarToken.address);
    });
    it("Should revert already initialized", async function () {
      await expect(
        gbarVault.initialize(gbarToken.address)
      ).to.be.rejectedWith("Initializable: contract is already initialized");
    });
    it("Should have 0 GBAR balance", async function () {
      expect(await gbarVault.getContractBalance()).to.equal("0");
    });
    it("Should have the right owner", async function () {
      expect(await gbarVault.owner()).to.equal(owner.address);
    });
    it("Should receive gbar mint tokens", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("1000", 6));
      expect(await gbarVault.getContractBalance()).to.equal(ethers.utils.parseUnits("1000", 6));
    });
  });
  describe("Owner functions", function () {
    it("Should be able to withdraw", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("1000", 6));
      await gbarVault.withdrawTo(alice.address, ethers.utils.parseUnits("1000", 6));
      expect(await gbarToken.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("1000", 6));
    });
    it("Should revert withdraw not owner", async function () {
      await expect(
        gbarVault.connect(alice).withdrawTo(alice.address, ethers.utils.parseUnits("1000", 6))
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert withdraw amount exceeds balance", async function () {
      await expect(
        gbarVault.withdrawTo(alice.address, ethers.utils.parseUnits("1000", 6))
      ).to.be.rejectedWith("AmountExceedsBalance");
    });
    it("Should revert withdraw amount is zero", async function () {
      await expect(
        gbarVault.withdrawTo(alice.address, "0")
      ).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should revert withdraw to address(0)", async function () {
      await expect(
        gbarVault.withdrawTo(ethers.constants.AddressZero, ethers.utils.parseUnits("1000", 6))
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
    it("Should be able to set new owner", async function () {
      await gbarVault.transferOwnership(alice.address);
      expect(await gbarVault.owner()).to.equal(alice.address);
    });
    it("Should not be able to set new owner from non-owner", async function () {
      await expect(
        gbarVault.connect(alice).transferOwnership(alice.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should set new gbar token address", async function () {
      const upgradedContract = await upgradeContract("GBAR", gbarToken.address);

      await gbarVault.setGBAR(upgradedContract.address);
      expect(await gbarVault.GbarToken()).to.equal(upgradedContract.address);
    });
    it("Should revert set new gbar token address not owner", async function () {
      const upgradedContract = await upgradeContract("GBAR", gbarToken.address);

      await expect(
        gbarVault.connect(alice).setGBAR(upgradedContract.address)
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should revert set new gbar address(0)", async function () {
      await expect(
        gbarVault.setGBAR(ethers.constants.AddressZero)
      ).to.be.rejectedWith("AddressCannotBeZero");
    });
  });
  describe("Deposit", function () {
    it("Should be able to deposit", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("1000", 6));
      await gbarVault.withdrawTo(alice.address, ethers.utils.parseUnits("1000", 6));
      await gbarToken.connect(alice).approve(gbarVault.address, ethers.utils.parseUnits("1000", 6));
      await gbarVault.connect(alice).deposit(ethers.utils.parseUnits("1000", 6));
      expect(await gbarVault.getContractBalance()).to.equal(ethers.utils.parseUnits("1000", 6));
    });
    it("Should revert not enough allowance", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("1000", 6));
      await expect(
        gbarVault.deposit(ethers.utils.parseUnits("1000", 6))
      ).to.be.rejectedWith("AmountExceedsAllowance");
    });
    it("Should revert amount exceeds allowance", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("1000", 6));
      await gbarToken.approve(owner.address, ethers.utils.parseUnits("1000", 6));
      await expect(
        gbarVault.deposit(ethers.utils.parseUnits("1001", 6))
      ).to.be.rejectedWith("AmountExceedsAllowance");
    });
    it("Should revert not enough balance", async function () {
      await gbarToken.approve(gbarVault.address, ethers.utils.parseUnits("1000", 6));
      await expect(
        gbarVault.deposit(ethers.utils.parseUnits("1000", 6))
      ).to.be.rejectedWith("ERC20: transfer amount exceeds balance");
    });
  });
  describe("Upgrading", function () {
    beforeEach("Change V1 state before upgrading", async function () {
      await gbarToken.mint(ethers.utils.parseUnits("10000", 6));
      await gbarVault.withdrawTo(alice.address, ethers.utils.parseUnits("1000", 6));

      expect(await gbarVault.getContractBalance()).to.equal(ethers.utils.parseUnits("9000", 6));

      const gbarVaultv2Factory = await ethers.getContractFactory("GBARVaultV2");
      gbarVaultV2 = await upgrades.upgradeProxy(gbarVault.address, gbarVaultv2Factory);
    });
    it("Should revert already initialized", async function () {
      await expect(
        gbarVaultV2.initialize(gbarToken.address)
      ).to.be.rejectedWith("Initializable: contract is already initialized");
    });
    it("Should revert owner not upgrading", async function () {
      const gbarVaultv2Factory = await ethers.getContractFactory("GBARVaultV2");
      await expect(
        upgrades.upgradeProxy(gbarVault.address, gbarVaultv2Factory.connect(alice))
      ).to.be.rejectedWith("Ownable: caller is not the owner");
    });
    it("Should have the right owner", async function () {
      expect(await gbarVaultV2.owner()).to.equal(owner.address);
    });
    it("Should have the right balances", async function () {
      expect(await gbarVaultV2.getContractBalance()).to.equal(ethers.utils.parseUnits("9000", 6));
    });
    it("Should have the right gbar token address", async function () {
      expect(await gbarVaultV2.GbarToken()).to.equal(gbarToken.address);
    });
    it("Should have the new function", async function () {
      expect(await gbarVaultV2.newFunction()).to.equal("newFunction");
    });
  });
});