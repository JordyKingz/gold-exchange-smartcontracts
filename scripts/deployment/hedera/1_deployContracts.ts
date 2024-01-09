import {
  Client,
  AccountId,
  PrivateKey,
  ContractCreateFlow,
  ContractFunctionParameters
} from "@hashgraph/sdk";
import { ethers } from "hardhat";
import * as dotenv from "dotenv";
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

dotenv.config();

const __TEST__ = true;

// Hedera Deployer Account
const operatorId = AccountId.fromString(
  `${process.env.HBAR_DEPLOYER_ACCOUNT_ID}`
);
const operatorKey = PrivateKey.fromString(
  `${process.env.HBAR_DEPLOYER_PRIVATE_KEY}`
);

if (operatorId === null || operatorKey === null) {
  throw new Error(
    "Environment variables myAccountId and myPrivateKey must be present"
  );
}

const ethAddress = process.env.EVM_ADDRESS;
const secondGuardAddress = process.env.RETRIEVAL_GUARD_ADDRESS;
if (!ethAddress) {
  throw new Error("Environment variables EVM_ADDRESS must be present");
}
if (!secondGuardAddress) {
  throw new Error(
    "Environment variables RETRIEVAL_GUARD_ADDRESS must be present"
  );
}

let companyVault = "";

if (__TEST__) {
  companyVault = `${process.env.COMPANY_ADDRESS_LOCAL}`;
} else {
  companyVault = `${process.env.COMPANY_ADDRESS}`;
}

if (companyVault === "" && __TEST__) {
  throw new Error("Environment variables COMPANY_ADDRESS_LOCAL must be present");
}
else if (companyVault === "" && !__TEST__) {
  throw new Error("Environment variables COMPANY_ADDRESS must be present");
}

const client = Client.forTestnet().setOperator(operatorId, operatorKey);

async function main() {
  await deployContract("GoldExchangeSwapHedera")
  // await deployContract("FeeProvider");
  // await deployOracle("GoldPriceOracle");

  return
}

async function deployContract(name: string, param?: string, paramTwo?: string) {
  const contract = await ethers.getContractFactory(`${name}`);
  let contractCreate: any;
  if (param && paramTwo) {
    contractCreate = new ContractCreateFlow()
      .setGas(10000000)
      .setConstructorParameters(
        new ContractFunctionParameters()
          .addAddress(`${param}`)
          .addAddress(`${paramTwo}`)
      )
      .setBytecode(contract.bytecode);
  } else if (param && !paramTwo) {
    contractCreate = new ContractCreateFlow()
      .setGas(10000000)
      .setConstructorParameters(
        new ContractFunctionParameters().addAddress(`${param}`)
      )
      .setBytecode(contract.bytecode);
  } else {
    contractCreate = new ContractCreateFlow()
      .setGas(10000000)
      .setBytecode(contract.bytecode);
  }

  const txResponse = await contractCreate.execute(client);
  const receipt = await txResponse.getReceipt(client);
  const contractId = receipt.contractId;
  if (contractId == null) {
    throw new Error("Contract ID was not returned");
  }
  const contractAddress = contractId.toSolidityAddress();
  console.log(
    `- The ${name} contract is deployed. \n smart contract ID is: ${contractId} \n`
  );
  console.log(
    `- The ${name} contract ID in Solidity format is: 0x${contractAddress} \n`
  );

  return {
    evm: `0x${contractAddress}`,
    hedera: contractId
  }
}

async function deployOracle(name: string) {
  const mainnetGoldPrice = await getLatestGoldPriceMainnet();
  const contract = await ethers.getContractFactory(`${name}`);
  const contractCreate = new ContractCreateFlow()
    .setGas(10000000)
    .setConstructorParameters(
      new ContractFunctionParameters().addInt256(mainnetGoldPrice.price.toString())
    )
    .setBytecode(contract.bytecode);

  const txResponse = await contractCreate.execute(client);
  const receipt = await txResponse.getReceipt(client);
  const contractId = receipt.contractId;
  if (contractId == null) {
    throw new Error("Contract ID was not returned");
  }
  const contractAddress = contractId.toSolidityAddress();
  console.log(
    `- The ${name} contract is deployed. \n smart contract ID is: ${contractId} \n`
  );
  console.log(
    `- The ${name} contract ID in Solidity format is: 0x${contractAddress} \n`
  );

  console.log(`- Gold price is set to ${mainnetGoldPrice.price} or in dollars: ${mainnetGoldPrice.priceInDollars} \n`)

  return {
    evm: `0x${contractAddress}`,
    hedera: contractId
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
