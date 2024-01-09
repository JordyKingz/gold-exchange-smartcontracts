import {
  Client,
  AccountId,
  PrivateKey,
  ContractExecuteTransaction,
  ContractFunctionParameters,
} from "@hashgraph/sdk";
import * as dotenv from "dotenv";

dotenv.config();

// Configure accounts and client
// @ts-ignore
const operatorId = AccountId.fromString(
  `${process.env.HBAR_DEPLOYER_ACCOUNT_ID}`
);
// @ts-ignore
const operatorKey = PrivateKey.fromString(
  `${process.env.HBAR_DEPLOYER_PRIVATE_KEY}`
);

if (operatorId === null || operatorKey === null) {
  throw new Error(
    "Environment variables myAccountId and myPrivateKey must be present"
  );
}

const goldId = process.env.HBAR_GOLD_TOKEN;
const gbarId = process.env.HBAR_GBAR_TOKEN;
const feeDistributorId = process.env.HBAR_FEE_DISTRIBUTOR;
const goldStakeVaultId = process.env.HBAR_GOLD_STAKE_VAULT;

if (!goldId) {
  throw new Error("Environment variables HBAR_GOLD_ADDRESS must be present");
}
if (!gbarId) {
  throw new Error("Environment variables HBAR_GBAR_ADDRESS must be present");
}
if (!feeDistributorId) {
  throw new Error(
    "Environment variables HBAR_FEE_DISTRIBUTOR_ADDRESS must be present"
  );
}
if (!goldStakeVaultId) {
  throw new Error(
    "Environment variables HBAR_GOLD_STAKE_POOL_ADDRESS must be present"
  );
}

const saucerSwapAddress = process.env.EVM_SAUCERSWAP_ROUTER;
const goldExchangeSwapAddress = process.env.EVM_GE_SWAP;
const feeProviderAddress = process.env.EVM_FEE_PROVIDER;
const goldTokenAddress = process.env.EVM_GOLD_TOKEN;
const gbarTokenAddress = process.env.EVM_GBAR_TOKEN;
const gbarVaultAddress = process.env.EVM_GBAR_VAULT;
const goldStakeVaultAddress = process.env.EVM_GOLD_STAKE_VAULT;
const feeDistributorAddress = process.env.EVM_FEE_DISTRIBUTOR;

if (!feeProviderAddress) {
  throw new Error("Environment variables EVM_FEE_PROVIDER must be present");
}
if (!gbarVaultAddress) {
  throw new Error("Environment variables EVM_GBAR_VAULT must be present");
}
if (!goldStakeVaultAddress) {
  throw new Error(
    "Environment variables ETH_GOLD_STAKE_POOL_ADDRESS must be present"
  );
}
if (!goldExchangeSwapAddress) {
  throw new Error(
    "Environment variables EVM_GOLD_EXCHANGE_SWAP must be present"
  );
}
if (!feeDistributorAddress) {
  throw new Error("Environment variables ETH_FEE_DISTRIBUTOR must be present");
}

const client = Client.forTestnet().setOperator(operatorId, operatorKey);

async function main() {
  // @ts-ignore
  await setConfig(goldId, "setGoldStakeVault", goldStakeVaultAddress);
  // @ts-ignore
  await setConfig(goldId, "setGbarToken", gbarTokenAddress);
  await setConfig(
    // @ts-ignore
    goldStakeVaultId,
    "setFeeDistributor",
    feeDistributorAddress
  );
  // @ts-ignore
  await setConfig(gbarId, "setFeeDistributor", feeDistributorAddress);
  // @ts-ignore
  // await setConfig(gbarId, "setFeeProvider", feeProviderAddress); // done in deployment
  // @ts-ignore
  await setConfig(gbarId, "setGBARVault", gbarVaultAddress);
  // @ts-ignore
  await setConfig(gbarId, "setGoldContract", goldTokenAddress);
  // @ts-ignore
  await setConfig(gbarId, "addFeeExclusion", feeDistributorAddress);
  // @ts-ignore
  await setConfig(gbarId, "addFeeExclusion", goldStakeVaultAddress);
  // @ts-ignore
  await setConfig(gbarId, "addFeeExclusion", gbarVaultAddress);
  // @ts-ignore
  await setConfig(gbarId, "addFeeExclusion", goldExchangeSwapAddress);
  // @ts-ignore
  await setConfig(gbarId, "addFeeExclusion", saucerSwapAddress);

  console.log("DONE");
}

async function setConfig(
  contractId: string,
  functionName: string,
  address: string
) {
  const transaction = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(10000000)
    .setFunction(
      functionName,
      new ContractFunctionParameters().addAddress(address)
    );

  const txResponse = await transaction.execute(client);

  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);

  // Get the transaction consensus status
  const transactionStatus = receipt.status;

  console.log("The transaction consensus status is " + transactionStatus);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
