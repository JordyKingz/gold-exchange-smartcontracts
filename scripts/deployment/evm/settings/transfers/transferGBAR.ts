import { ethers } from "hardhat";

const DAY = 86400; // 1 day in seconds

const fastForward = async function (seconds: any) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
};

const sleep = async function (ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

async function main() {
  const [owner,
    alice,
    bob,
    charlie,
    dave,
    eve] = await ethers.getSigners();

  const gbarAddress = process.env.GBAR_CONTRACT_LOCAL;
  const gbarContract = await ethers.getContractFactory("GBAR");
  const gbarInstance = await gbarContract.attach(`${gbarAddress}`);

  let counter = 0;
  while (counter < 10) {
    // transfer gbar between accounts
    await gbarInstance
      .connect(alice)
      .transfer(bob.address, ethers.utils.parseUnits("8000", 6));

    await gbarInstance
      .connect(bob)
      .transfer(charlie.address, ethers.utils.parseUnits("10000", 6));

    await gbarInstance
      .connect(charlie)
      .transfer(dave.address, ethers.utils.parseUnits("25000", 6));

    await gbarInstance
      .connect(dave)
      .transfer(eve.address, ethers.utils.parseUnits("1000", 6));

    counter++;
  }
  await gbarInstance
    .connect(eve)
    .transfer(alice.address, ethers.utils.parseUnits("1000000", 6));

  const feeDistributor = process.env.FEE_DISTRIBUTOR;

  const balance = await gbarInstance.balanceOf(feeDistributor);
  console.log("balance of fee distributor: ", balance.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
