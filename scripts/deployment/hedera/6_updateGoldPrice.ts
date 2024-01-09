import {
  Client,
  AccountId,
  PrivateKey,
  ContractExecuteTransaction,
  ContractFunctionParameters, ContractCallQuery, ContractFunctionResult,
} from "@hashgraph/sdk";
import * as dotenv from "dotenv";
import {ethers} from "ethers";
import {getLatestGoldPriceMainnet} from "../../utils/helpers";

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

const goldOracleId = process.env.HBAR_GOLD_ORACLE || "";

if (!goldOracleId) {
  throw new Error("Environment variables HBAR_GOLD_ORACLE must be present");
}

const client = Client.forTestnet().setOperator(operatorId, operatorKey);

async function main() {
 const result = await getLatestGoldPriceMainnet();
  console.log(`Current mainnet XAU/USD price: ${result.priceInDollars.toFixed(3)}`);

  await setGoldPrice(goldOracleId, parseInt(result.price.toString()));

  await getGoldPrice(goldOracleId);
}

async function setGoldPrice(
  contractId: string,
  goldValue: number
) {

  const transaction = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(10000000)
    .setFunction(
      "setLatestPrice",
      // @ts-ignore
      new ContractFunctionParameters().addInt256(goldValue)
    );

  const txResponse = await transaction.execute(client);

  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);

  // Get the transaction consensus status
  const transactionStatus = receipt.status;

  console.log("The transaction consensus status is " + transactionStatus);
}

async function getGoldPrice(contractId: string) {
  const tx = new ContractCallQuery()
    .setContractId(contractId)
    .setGas(100000)
    .setFunction(
      "getLatestPrice"
    );

  const txExecuted: ContractFunctionResult = await tx.execute(client);
  console.log(`XAU/USD price set: ${txExecuted.getInt256(0)}`);
}



main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
