import { ethers, upgrades } from "hardhat";

async function main() {
  const [
    owner,
    guardOne,
    guardTwo
  ] = await ethers.getSigners();

//   const gbarAddress = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
//
//   const upgradableGBAR = await ethers.getContractFactory("GBARV2");
//   const upgraded = await upgrades.upgradeProxy(gbarAddress, upgradableGBAR);
//   console.log("GBAR Upgraded", upgraded.address);
//
//   // call newFunction from upgraded contract
//   const newFunctionResult = await upgraded.newFunction();
//   console.log("newFunctionResult", newFunctionResult);
//
//   const retrievalGuardCounter = await upgraded.getRetrievalRetrievalGuardsCount();
//   console.log("retrievalGuardCounter", retrievalGuardCounter);
//
//   const feeProvider = await upgraded.FEE_PROVIDER();
//   console.log("feeProvider", feeProvider);
//
//   const extraNewFunction = await upgraded.extraNewFunction();
//   console.log("extraNewFunction", extraNewFunction);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
