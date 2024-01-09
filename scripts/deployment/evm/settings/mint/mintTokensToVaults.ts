import {ethers} from "hardhat";

let goldAddress: string;
let goldVault: string;
let gbarAddress: string;
let gbarVault: string;

goldAddress = process.env.GOLD_TOKEN || "";
goldVault = process.env.GOLD_VAULT || "";
gbarAddress = process.env.GBAR_TOKEN || "";
gbarVault = process.env.GBAR_VAULT || "";

async function main() {
  const [
    owner,
  ] = await ethers.getSigners();
  try {
    const goldContract = await ethers.getContractFactory("GOLD");
    const goldInstance = await goldContract.attach(`${goldAddress}`);
    await goldInstance.mint(`${goldVault}`, 20000); // mint 20000 Gold to gold vault

    const gbarContract = await ethers.getContractFactory("GBAR");
    const gbarInstance = await gbarContract.attach(`${gbarAddress}`);
    await gbarInstance.mint(ethers.utils.parseUnits("1104660", 6)); // mint 1104660 GBAR
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
