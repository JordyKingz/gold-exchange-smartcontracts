import { expect } from "chai";
import { ethers } from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";
import {deployAllContracts, getLatestGoldPriceMainnet} from "../../scripts/utils/helpers";

let goldPriceOracle: any;
let feeProvider: any;
let goldToken: any;
let gbarToken: any;
let gbarVault: any;
let feeDistributor: any;
let goldStakeVault: any;

let owner: any;
let alice: any;
let bob: any;
let charlie: any;
let dave: any;
let company: any;

let retrievalGuardList: string[] = [];

describe("Gold token contract", function () {
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
    it("Should set the right owner", async function () {
      expect(await goldToken.owner()).to.equal(owner.address);
    });
    it("Should set the right decimals", async function () {
      expect(await goldToken.decimals()).to.equal(0);
    });
    it("Should set the right name", async function () {
      expect(await goldToken.name()).to.equal("GOLD");
    });
    it("Should set the right symbol", async function () {
      expect(await goldToken.symbol()).to.equal("GOLD");
    });
    it("Should have the right gold price oracle address", async function () {
      expect(await goldToken.goldOracleAddress()).to.equal(goldPriceOracle.address);
    });
  });
  describe("Contract configs", function() {
    it("Should have Stake Vault address(0)", async function () {
      expect(await goldToken.stakeVaultAddress()).to.equal(ethers.constants.AddressZero);
    });
    it("Should have GBAR address(0)", async function () {
      expect(await goldToken.gbarAddress()).to.equal(ethers.constants.AddressZero);
    });
  });
  describe("Contract functions", function() {
    beforeEach(async function () {
      await goldToken.setGoldStakeVault(goldStakeVault.address);
      await goldToken.setGbarToken(gbarToken.address);
    });
    it("Should set the right stake vault address", async function () {
      expect(await goldToken.stakeVaultAddress()).to.equal(goldStakeVault.address);
    });
    it("Should set the right gbar address", async function () {
      expect(await goldToken.gbarAddress()).to.equal(gbarToken.address);
    });
    describe("Owner functions", function() {
      it("Should set the right gold price oracle address", async function () {
        await goldToken.setGoldPriceOracle(alice.address);
        expect(await goldToken.goldOracleAddress()).to.equal(alice.address);
      });
      it("Should revert set gold price oracle address to address(0)", async function () {
        await expect(goldToken.setGoldPriceOracle(ethers.constants.AddressZero)).to.be.rejectedWith("AddressCannotBeZero");
      });
      it("Should revert set gold price oracle no owner", async function () {
        await expect(goldToken.connect(alice).setGoldPriceOracle(alice.address)).to.be.rejectedWith("Ownable: caller is not the owner");
      });
      it("Should set the right gbar token address", async function () {
        await goldToken.setGbarToken(alice.address);
        expect(await goldToken.gbarAddress()).to.equal(alice.address);
      });
      it("Should revert set gbar token address to address(0)", async function () {
        await expect(goldToken.setGbarToken(ethers.constants.AddressZero)).to.be.rejectedWith("AddressCannotBeZero");
      });
      it("Should revert set gbar token no owner", async function () {
        await expect(goldToken.connect(alice).setGbarToken(alice.address)).to.be.rejectedWith("Ownable: caller is not the owner");
      });
      it("Should set the new gold stake vault address", async function () {
        await goldToken.setGoldStakeVault(alice.address);
        expect(await goldToken.stakeVaultAddress()).to.equal(alice.address);
      });
      it("Should revert set new gold stake vault address to address(0)", async function () {
        await expect(goldToken.setGoldStakeVault(ethers.constants.AddressZero)).to.be.rejectedWith("AddressCannotBeZero");
      });
      it("Should revert set new gold stake vault no owner", async function () {
        await expect(goldToken.connect(alice).setGoldStakeVault(alice.address)).to.be.rejectedWith("Ownable: caller is not the owner");
      });
      describe("Mint function", function() {
        it("Should mint 1000 GOLD to alice", async function () {
          await goldToken.mint(alice.address, 1000);
          expect(await goldToken.balanceOf(alice.address)).to.equal(1000);
        });
        it("Should revert mint is zero", async function () {
          await expect(goldToken.mint(alice.address, 0)).to.be.rejectedWith("AmountCannotBeZero");
        });
        it("Should revert mint to is address(0)", async function () {
          await expect(goldToken.mint(ethers.constants.AddressZero, 1000)).to.be.rejectedWith("MintToAddressZero");
        });
        it("Should revert not owner calling mint", async function () {
          await expect(goldToken.connect(alice).mint(alice.address, 1000)).to.be.rejectedWith("Ownable: caller is not the owner");
        });
      });
      describe("Mint Gold and GBAR", function() {
        it("Should mint 1000 GOLD to alice and GBAR value to vault", async function () {
          await goldToken.mintGoldAndGbar(alice.address, 1000);
          expect(await goldToken.balanceOf(alice.address)).to.equal(1000);

          const gbarValue = await goldPriceOracle.getGoldGbarConversion(1000);
          expect(await gbarToken.balanceOf(gbarVault.address)).to.equal(gbarValue[2].toString());
        });
        it("Should revert mint is zero", async function () {
          await expect(goldToken.mintGoldAndGbar(alice.address, 0)).to.be.rejectedWith("AmountCannotBeZero");
        });
        it("Should revert mint to is address(0)", async function () {
          await expect(goldToken.mintGoldAndGbar(ethers.constants.AddressZero, 1000)).to.be.rejectedWith("MintToAddressZero");
        });
        it("Should revert not owner calling mint", async function () {
          await expect(goldToken.connect(alice).mintGoldAndGbar(alice.address, 1000)).to.be.rejectedWith("Ownable: caller is not the owner");
        });
      });
      describe("Stake Mint", function() {
        it("Should stake mint 1000 GOLD tokens", async function () {
          await goldToken.stakeMint(alice.address, 1000);
          const stakeEntry = await goldStakeVault.Stakers(alice.address);
          expect(stakeEntry.totalStaked.toString()).to.equal('1000');
        });
        it("Should revert mint is zero", async function () {
          await expect(goldToken.stakeMint(alice.address, 0)).to.be.rejectedWith("AmountCannotBeZero");
        });
        it("Should revert mint to is address(0)", async function () {
          await expect(goldToken.stakeMint(ethers.constants.AddressZero, 1000)).to.be.rejectedWith("MintToAddressZero");
        });
        it("Should revert not owner calling mint", async function () {
          await expect(goldToken.connect(alice).stakeMint(alice.address, 1000)).to.be.rejectedWith("Ownable: caller is not the owner");
        });
      });
    });
  });
});
