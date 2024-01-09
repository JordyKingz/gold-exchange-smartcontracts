import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  mocha: {
    timeout: 100000000, // 100s for unit tests
  },
  networks: {
    hardhat: {
      forking: {
        url: `${process.env.BSCTEST_URL}`
      }
    },
    localhost: {
      url: "http://localhost:8545",
    },
    hedera: { // hedera testnet RPC
      url: "https://testnet.hedera.com",
      // @ts-ignore
      accounts: [process.env.EVM_PRIVATE_KEY],
    },
    goerli: { // deprecated testnet at the end of 2023. Use sepolia instead
      url: process.env.GOERLI_URL,
      // @ts-ignore
      accounts: [process.env.GOERLI_PRIVATE_KEY],
    },
    sepolia: {
      url: process.env.SEPOLIA_URL,
      // @ts-ignore
      accounts: [process.env.SEPOLIA_PRIVATE_KEY],
    },
    bsctest: {
      url: process.env.BSCTEST_URL,
      // @ts-ignore
      accounts: [process.env.BSCTEST_PRIVATE_KEY],
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
