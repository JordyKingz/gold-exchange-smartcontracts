import {ethers} from "hardhat";
import {ContractService} from "../service/ContractService";
import ClientManagement from "../utils/ClientManagement";
import {ContractExecuteTransaction, ContractFunctionParameters} from "@hashgraph/sdk";

const contractService = new ContractService();
const clientManagement = new ClientManagement();
const client = clientManagement.createClientAsAdmin();

let goldId: string;
let goldVaultEvm: string;
let gbarId: string;
let gbarVaultId: string;

goldId = process.env.HBAR_GOLD_TOKEN || "";
goldVaultEvm = process.env.EVM_GOLD_VAULT || "";
gbarId = process.env.HBAR_GBAR_TOKEN || "";
gbarVaultId = process.env.HBAR_GBAR_VAULT || "";

async function main() {
  // Mint 20000 / 20KG GOLD
  await mintGold(goldVaultEvm, 20000);
  // (20000 * 64.98) * 0.85 = 1104660
  await mintGBAR(ethers.utils.parseUnits("1104660", 6))
}

async function mintGold(to: string, amount: number){
  const transaction = new ContractExecuteTransaction()
    .setContractId(goldId)
    .setGas(10000000)
    .setFunction(
      "mint",
      new ContractFunctionParameters()
        .addAddress(to)
        .addUint256(amount)
    );
  const txResponse = await transaction.execute(client);
  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);
  // Get the transaction consensus status
  const transactionStatus = receipt.status;
  console.log("The transaction consensus status is " + transactionStatus);
}

async function mintGBAR(amount: any) {
  const transaction = new ContractExecuteTransaction()
    .setContractId(gbarId)
    .setGas(10000000)
    .setFunction(
      "mint",
      new ContractFunctionParameters()
        .addUint256(amount.toString())
    );
  const txResponse = await transaction.execute(client);
  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);
  // Get the transaction consensus status
  const transactionStatus = receipt.status;
  console.log("The transaction consensus status is " + transactionStatus);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
