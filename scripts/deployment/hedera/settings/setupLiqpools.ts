import {ethers} from "hardhat";
import {ContractService} from "../service/ContractService";
import ClientManagement from "../utils/ClientManagement";
import {ContractExecuteTransaction, ContractFunctionParameters} from "@hashgraph/sdk";

const contractService = new ContractService();
const clientManagement = new ClientManagement();
const client = clientManagement.createClientAsAdmin();

let goldId: string;
let goldEvm: string;
let goldVaultId: string;
let gbarId: string;
let gbarEvm: string;
let gbarVaultId: string;
let geSwapId: string;
let geSwapEvm: string;

goldId = process.env.HBAR_GOLD_TOKEN || "";
goldEvm = process.env.EVM_GOLD_TOKEN || "";
goldVaultId = process.env.HBAR_GOLD_VAULT || "";
gbarId = process.env.HBAR_GBAR_TOKEN || "";
gbarEvm = process.env.EVM_GBAR_TOKEN || "";
gbarVaultId = process.env.HBAR_GBAR_VAULT || "";
geSwapId = process.env.HBAR_GE_SWAP || "";
geSwapEvm = process.env.EVM_GE_SWAP || "";

let ownerEvm = process.env.EVM_ADDRESS || "";

async function main() {
  const hbarGoldLiquidity = 21293; //ethers.utils.parseEther("21293"); // $1040
  const goldAmount = ethers.utils.parseUnits("16", 0); // $1040;
  await withdrawFromVault(goldVaultId, goldAmount.toString()); // tx response = 22
  await approveToken(goldId, geSwapEvm, goldAmount.toString());
  await addLiquidity(goldEvm, goldAmount.toString(), hbarGoldLiquidity.toString());

  const hbarGbarLiquidity = 5000; //ethers.utils.parseEther("5000"); // $244
  const gbarAmount = ethers.utils.parseUnits("244", 6);
  await withdrawFromVault(gbarVaultId, gbarAmount.toString());
  await approveToken(gbarId, geSwapEvm, gbarAmount.toString());
  await addLiquidity(gbarEvm, gbarAmount.toString(), hbarGbarLiquidity.toString());
}

async function withdrawFromVault(contractId: string, tokenAmount: string) {
  const transaction = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(10000000)
    .setFunction(
      "withdrawTo",
      new ContractFunctionParameters()
        .addAddress(ownerEvm)
        .addUint256(Number(tokenAmount))
    );
  const txResponse = await transaction.execute(client);
  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);
  // Get the transaction consensus status
  const transactionStatus = receipt.status;
  console.log("The transaction consensus status is " + transactionStatus);
}

async function approveToken(contractId: string, spender: string, amount: string) {
  const transaction = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(10000000)
    .setFunction(
      "approve",
      new ContractFunctionParameters()
        .addAddress(spender)
        .addUint256(Number(amount))
    );
  const txResponse = await transaction.execute(client);
  // Request the receipt of the transaction
  const receipt = await txResponse.getReceipt(client);
  // Get the transaction consensus status
  const transactionStatus = receipt.status;
  console.log("The transaction consensus status is " + transactionStatus);
}

async function addLiquidity(tokenAddress: string, tokenLiq: string, hbarLiquidity: string) {
  const transaction = new ContractExecuteTransaction()
    .setContractId(geSwapId)
    .setGas(10000000)
    .setFunction(
      "addLiquidityETH",
      new ContractFunctionParameters()
        .addAddress(tokenAddress)
        .addUint256(Number(tokenLiq))
    )
    .setPayableAmount(hbarLiquidity);
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
