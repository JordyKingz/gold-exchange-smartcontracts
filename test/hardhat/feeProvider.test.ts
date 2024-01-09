import { expect } from "chai";
import { ethers } from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";

describe("Fee provider contract", function () {
  let feeProviderInstance: any;

  beforeEach(async function () {
    const feeProvider = await ethers.getContractFactory("FeeProvider");
    feeProviderInstance = await feeProvider.deploy();
  });

  describe("Test fees", function () {
    it("0 input", async function () {
      const result = await feeProviderInstance.getFee(0);
      expect(result).to.equal(0);
    });

    it("1 - 100 input", async function () {
      for (let i = 1; i <= 100; i++) {
        const amount = i.toString();
        const result = await feeProviderInstance.getFee(
          ethers.utils.parseUnits(amount, 6)
        );
        const calculated = i / 100;
        expect(result).to.equal(
          ethers.utils.parseUnits(calculated.toString(), 6)
        );
      }
    });

    it("100000 - 1000000 input", async function () {
      for (let i = 100000; i <= 1000000; i += 100000) {
        const amount = i.toString();
        const result = await feeProviderInstance.getFee(
          ethers.utils.parseUnits(amount, 6)
        );
        const calculated = 1 + 0.000024 * i;
        expect(result).to.equal(
          ethers.utils.parseUnits(calculated.toString(), 6)
        );
      }
    });

    it("more than 1000000 input", async function () {
      for (let i = 1000000; i <= 10000000; i += 1000000) {
        const amount = i.toString();
        const result = await feeProviderInstance.getFee(
          ethers.utils.parseUnits(amount, 6)
        );
        expect(result).to.equal(ethers.utils.parseUnits("25", 6));
      }
    });
  });
});
