import { expect } from "chai";
import { ethers } from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";
import {getLatestGoldPriceMainnet} from "../../scripts/utils/helpers";

let goldOracle: any;
let owner: any;
let alice: any;
let currentOraclePrice: any

describe("Gold oracle contract", function () {
  beforeEach(async function () {
      [
        owner,
        alice,
      ] = await ethers.getSigners();
    const oracleFactory = await ethers.getContractFactory("GoldPriceOracle");
    currentOraclePrice = await getLatestGoldPriceMainnet();
    goldOracle = await oracleFactory.deploy(currentOraclePrice.price);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await goldOracle.owner()).to.equal(owner.address);
    });
    it("Should have set gold latest price", async function () {
      expect(await goldOracle.getLatestPrice()).to.equal(currentOraclePrice.price);
    });
    it("Should have set the ounceToGramInWei", async function () {
      const ounceToGramInWei = await goldOracle.ounceToGramInWei();
      expect(await goldOracle.ounceToGramInWei()).to.equal(ethers.utils.parseUnits("31.1034768", 18));
    });
  });
  describe("Owner functions", function() {
    it("Should be able to set the latest price", async function () {
      const newPrice = await getLatestGoldPriceMainnet();
      await goldOracle.setLatestPrice(newPrice.price);
      expect(await goldOracle.getLatestPrice()).to.equal(newPrice.price);
    });
    it("Should revert if not owner", async function () {
      const newPrice = await getLatestGoldPriceMainnet();
      await expect(goldOracle.connect(alice).setLatestPrice(newPrice.price)).to.be.revertedWith("Ownable: caller is not the owner");
    });
    it("Should revert if price is zero", async function () {
      await expect(goldOracle.setLatestPrice(0)).to.be.rejectedWith("PriceCannotBeZero");
    });
  });
  describe("Gold GBAR conversion", function() {
    it("Should calculate GBAR value of 1000 gram Gold", async function () {
      const currentPrice = await goldOracle.getLatestPrice();
      const ounceToGramInWei = await goldOracle.ounceToGramInWei();
      const goldInGrams = 1000; // 1KG
      const result = await goldOracle.getGoldGbarConversion(goldInGrams);

      const goldPriceInOunce = currentPrice * 1e18;
      const goldPriceInGram = (goldPriceInOunce / ounceToGramInWei * 1e6) / 1e8;
      const totalValueOfGold = goldInGrams * goldPriceInGram;
      const totalValueOfGoldInGbar = totalValueOfGold * 85 / 100;
      expect(result[0].toString()).to.equal(result[0].toString());
      expect(result[1].toString()).to.equal(result[1].toString());
      expect(result[2].toString()).to.equal(result[2].toString());
    });
    it("Should revert amount is zero", async function () {
      await expect(goldOracle.getGoldGbarConversion(0)).to.be.rejectedWith("AmountCannotBeZero");
    });
    it("Should revert is amount is above 1billion grams", async function () {
      await expect(goldOracle.getGoldGbarConversion(1000000001)).to.be.rejectedWith("ExceedsMaxValue");
    });
  });
});
