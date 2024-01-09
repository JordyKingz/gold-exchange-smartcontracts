import {ethers} from "hardhat";

let goldAddress: string;
let goldVault: string;
let gbarAddress: string;
let gbarVaultAddress: string;

goldAddress = process.env.GOLD_TOKEN || "";
goldVault = process.env.GOLD_VAULT || "";
gbarAddress = process.env.GBAR_TOKEN || "";
gbarVaultAddress = process.env.GBAR_VAULT || "";

async function main() {
  const [
    owner,
  ] = await ethers.getSigners();
  try {
    const goldContract = await ethers.getContractFactory("GOLD");
    const goldInstance = await goldContract.attach(`${goldAddress}`);
    await goldInstance.mint(`${owner.address}`, 10);

    const gbarContract = await ethers.getContractFactory("GBAR");
    const gbarInstance = await gbarContract.attach(`${gbarAddress}`);
    await gbarInstance.mint(ethers.utils.parseUnits("650", 6));

    const gbarVaultFactory = await ethers.getContractFactory("GBARVault");
    const gbarVaultInstance = await gbarVaultFactory.attach(`${gbarVaultAddress}`);
    await gbarVaultInstance.withdrawTo(owner.address, ethers.utils.parseUnits("650", 6));
  } catch(e) {
    console.log(e);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
