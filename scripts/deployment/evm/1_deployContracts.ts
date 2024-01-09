import { ethers, upgrades } from "hardhat";
import {getLatestGoldPriceMainnet} from "../../utils/helpers";

/*
  Deploy smart contracts to the chain.

  There is a specific order in which the contracts need to be deployed.
  1. Deploy GoldExchangeSwap contract. Will be used for swapping GOLD and GBAR tokens on Uniswap.
  2. Deploy FeeProvider contract. Will be used for calculating fees on GBAR transactions.
  3. Deploy GoldPriceOracle contract. Gold price is fetched from Chainlink
     Will be used for calculating the cap for GOLD vault
  4. Deploy GOLD contract. GoldPriceOracle address will be set during deployment.
  5. Deploy GoldVault contract. Will be used for buying and selling GOLD tokens.
  6. Deploy GBAR contract. Set feeProvider, number of required signatures, and retrievalGuardList.
  7. Deploy GBARVault contract. Minted GBAR tokens will be sent to this contract.
  8. Deploy GoldStakeVault contract. Will be used for staking GOLD tokens.
  9. Deploy FeeDistributor contract. Will be used for distributing fees to the stake vaults.
*/

async function main() {
  const [
    owner,
    guardOne,
    guardTwo
  ] = await ethers.getSigners();

  const __TEST__ = true;

  let companyVault = "";

  if (__TEST__) {
    companyVault = `${process.env.COMPANY_ADDRESS}`;
  } else {
    companyVault = `${process.env.COMPANY_ADDRESS}`;
  }

  if (companyVault === "") {
    throw new Error("Missing environment variables");
  }

  const swapFactory = await ethers.getContractFactory("GoldExchangeSwapV2");
  const swap = await swapFactory.deploy();
  await swap.deployed();
  console.log("Swap deployed to:", swap.address);
  console.log("\n");

  const provider = await ethers.getContractFactory("FeeProvider");
  const providerInstance = await provider.deploy();
  await providerInstance.deployed();
  console.log("FeeProvider deployed", providerInstance.address);
  console.log("\n");

  // Set Chainlink gold price during deployment
  const mainnetGoldPrice = await getLatestGoldPriceMainnet();
  const goldOracle = await ethers.getContractFactory("GoldPriceOracle");
  const goldOracleInstance = await goldOracle.deploy(mainnetGoldPrice.price);
  await goldOracleInstance.deployed();
  console.log(`Gold Price Oracle deployed: ${goldOracleInstance.address}, with Gold Price ${mainnetGoldPrice.priceInDollars} or ${mainnetGoldPrice.price}`);
  console.log("\n");

  const upgradableGold = await ethers.getContractFactory("GOLD");
  const gold = await upgrades.deployProxy(upgradableGold,
    [goldOracleInstance.address],
    { initializer: 'initialize' });
  await gold.deployed();
  console.log("GOLD deployed to:", gold.address);
  console.log("\n");

  const upgradableGoldVault = await ethers.getContractFactory("GoldVault");
  const goldVault = await upgrades.deployProxy(upgradableGoldVault,
    [
      gold.address,
    ],
    { initializer: 'initialize' });
  await goldVault.deployed();
  console.log("Gold Vault deployed to:", goldVault.address);
  console.log("\n");

  const retrievalGuardList = [owner.address, companyVault]; // todo add guardOne & guardTwo in .env
  const upgradableGBAR = await ethers.getContractFactory("GBAR");
  const gbar = await upgrades.deployProxy(upgradableGBAR,
    [
      providerInstance.address,
      gold.address,
      goldOracleInstance.address,
      2,
      retrievalGuardList
    ],
    { initializer: 'initialize' });
  await gbar.deployed();
  console.log("GBAR deployed to:", gbar.address);
  console.log("\n");

  const upgradableGBARVault = await ethers.getContractFactory("GBARVault");
  const gbarVault = await upgrades.deployProxy(upgradableGBARVault,
    [
      gbar.address,
    ],
    { initializer: 'initialize' });
  await gbarVault.deployed();
  console.log("GBAR Vault deployed to:", gbarVault.address);
  console.log("\n");

  const upgradableGoldStakeVault = await ethers.getContractFactory("GoldStakeVault");
  const goldStakeVault = await upgrades.deployProxy(upgradableGoldStakeVault,
    [gold.address, gbar.address],
    { initializer: 'initialize' });
  await goldStakeVault.deployed();
  console.log("GOLD Stake Vault deployed to:", goldStakeVault.address);
  console.log("\n");

  const upgradableFeeDistributor = await ethers.getContractFactory("FeeDistributor");
  const feeDistributor = await upgrades.deployProxy(upgradableFeeDistributor,
    [gbar.address, goldStakeVault.address, companyVault, goldOracleInstance.address],
    { initializer: 'initialize' });
  await feeDistributor.deployed();
  console.log("Fee Distributor deployed to:", feeDistributor.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
