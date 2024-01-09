import {ethers } from "ethers";
import {ethers as ethersHardhat } from "hardhat";
import {getLatestGoldPriceMainnet} from "../../../utils/helpers";

let goldOracleAddress = process.env.GOLD_ORACLE || "";

async function main() {
  const [owner] = await ethersHardhat.getSigners();
  // get gold price from mainnet
  const result = await getLatestGoldPriceMainnet();
  console.log(`Current mainnet XAU/USD price: ${result.priceInDollars.toFixed(3)}`);


  // update gold price in our oracle
  const goldOracleFactory = await ethersHardhat.getContractFactory("GoldPriceOracle");
  const goldOracle = await goldOracleFactory.attach(`${goldOracleAddress}`);
  console.log(`settings price to ${result.price.toString()}`);

  // result price to int
  await goldOracle.setLatestPrice(parseInt(result.price.toString()));
  const goldPriceSet = await goldOracle.getLatestPrice();
  console.log(`Gold price set: ${goldPriceSet.toString()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
