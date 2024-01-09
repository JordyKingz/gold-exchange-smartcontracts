import { ethers } from "hardhat";

const sleep = async function (ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

const __TEST__ = true;

let goldExchangeSwap: string;
let feeProvider: string;
let goldOracle: string;
let goldAddress: string;
let gbarAddress: string;
let gbarVaultAddress: string;
let goldStakeVaultAddress: string;
let feeDistributorAddress: string;
let uniswapV2Router: string;

goldExchangeSwap = process.env.GE_SWAP || "";
feeProvider = process.env.FEE_PROVIDER || "";
goldOracle = process.env.GOLD_ORACLE || "";
goldAddress = process.env.GOLD_TOKEN || "";
gbarAddress = process.env.GBAR_TOKEN || "";
gbarVaultAddress = process.env.GBAR_VAULT || "";
goldStakeVaultAddress = process.env.GOLD_STAKE_VAULT || "";
feeDistributorAddress = process.env.FEE_DISTRIBUTOR || "";
uniswapV2Router = process.env.UNISWAP_V2_ROUTER || "";

async function main() {
  const [owner, guard] = await ethers.getSigners();

  const goldContract = await ethers.getContractFactory("GOLD");
  const goldInstance = await goldContract.attach(`${goldAddress}`);

  const stakeVaultFactory = await ethers.getContractFactory("GoldStakeVault");
  const vaultInstance = await stakeVaultFactory.attach(`${goldStakeVaultAddress}`);

  const gbarContract = await ethers.getContractFactory("GBAR");
  const gbarInstance = await gbarContract.attach(`${gbarAddress}`);

  // GOLD Settings
  await goldInstance.setGoldStakeVault(`${goldStakeVaultAddress}`);
  await goldInstance.setGbarToken(`${gbarAddress}`);
  // GOLD STAKE VAULT Settings
  await vaultInstance.setFeeDistributor(`${feeDistributorAddress}`);
  // GBAR Settings
  await gbarInstance.setFeeDistributor(`${feeDistributorAddress}`);
  await gbarInstance.setGBARVault(`${gbarVaultAddress}`);
  await gbarInstance.setGoldContract(`${goldAddress}`);
  // GBAR fee exclusions
  await gbarInstance.addFeeExclusion(`${goldStakeVaultAddress}`);
  await gbarInstance.addFeeExclusion(`${feeDistributorAddress}`);
  await gbarInstance.addFeeExclusion(`${gbarVaultAddress}`);
  // Add UniswapV2 to GBAR fee exclusions
  await gbarInstance.addFeeExclusion(`${uniswapV2Router}`);
  // Add GE Swap to GBAR fee exclusions
  await gbarInstance.addFeeExclusion(`${goldExchangeSwap}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
