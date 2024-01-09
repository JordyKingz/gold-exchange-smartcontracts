import {DeployedContract} from "./model/contract";
import dotenv from "dotenv";
import {ContractService} from "./service/ContractService";
import {ContractExecuteTransaction, ContractFunctionParameters} from "@hashgraph/sdk";
import ClientManagement from "./utils/ClientManagement";
dotenv.config();

const contractService = new ContractService();
const clientManagement = new ClientManagement();

const client = clientManagement.createClientAsAdmin();
const { adminKey } = clientManagement.getAdmin();


const feeProviderEvm = process.env.EVM_FEE_PROVIDER || "";
const goldOracleEvm = process.env.EVM_GOLD_ORACLE || "";
const goldTokenEvm = process.env.EVM_GOLD_TOKEN || "";
const gbarTokenEvm = process.env.EVM_GBAR_TOKEN || "";
const goldStakeVaultEvm = process.env.EVM_GOLD_STAKE_VAULT || "";

const ownerAddress = process.env.EVM_ADDRESS || "";
const guardAddress = process.env.RETRIEVAL_GUARD_ADDRESS || "";
let companyVault = `${process.env.COMPANY_ADDRESS}`;

if (companyVault === "") {
  throw new Error("Environment variables COMPANY_ADDRESS must be present");
}

async function main() {
  await initialize("GOLD", goldOracleEvm);
  await initialize("GoldVault", goldTokenEvm);
  await initializeGBAR("GBAR");
  await initialize("GBARVault", gbarTokenEvm);
  await initialize("GoldStakeVault", goldTokenEvm, gbarTokenEvm);
  await initializeDistributor("FeeDistributor", gbarTokenEvm, goldStakeVaultEvm, companyVault, goldOracleEvm);
  return "Done";
}


async function initialize(contractName: string, addressOne?: string, addressTwo?: string) {
  const contractBeingDeployed: DeployedContract =
    contractService.getContract(contractName);

  console.log(`Contract being initialized: ${contractBeingDeployed.id}`)

  let tx;
  if (addressOne && addressOne !== "" && !addressTwo) {
    tx = new ContractExecuteTransaction()
      .setContractId(contractBeingDeployed.id)
      .setGas(2000000)
      .setFunction(
        "initialize",
        new ContractFunctionParameters()
          .addAddress(addressOne)
      )
  } else if (addressOne && addressOne !== "" && addressTwo && addressTwo !== "") {
    tx = new ContractExecuteTransaction()
      .setContractId(contractBeingDeployed.id)
      .setGas(2000000)
      .setFunction(
        "initialize",
        new ContractFunctionParameters()
          .addAddress(addressOne)
          .addAddress(addressTwo)
      )
  }

  if (tx) {
    const txExecute = await tx.execute(client);
    const txResponse = await txExecute.getRecord(client);
    console.log(txResponse);
  } else {
    console.log("tx was not created");
  }
}

async function initializeGBAR(contractName: string) {
  const contractBeingDeployed: DeployedContract =
    contractService.getContract(contractName);

  console.log(`Contract being initialized: ${contractBeingDeployed.id}`)

  const tx = new ContractExecuteTransaction()
    .setContractId(contractBeingDeployed.id)
    .setGas(2000000)
    .setFunction(
      "initialize",
      new ContractFunctionParameters()
        .addAddress(`${feeProviderEvm}`)
        .addAddress(`${goldTokenEvm}`)
        .addAddress(`${goldOracleEvm}`)
        .addUint8(2)
        .addAddressArray([`${ownerAddress}`, `${guardAddress}`])
    )

  const txExecute = await tx.execute(client);
  const txResponse = await txExecute.getRecord(client);
  console.log(txResponse);
}

async function initializeDistributor(contractName: string, addressOne?: string, addressTwo?: string, addressThree?: string, addressFour?: string) {
  const contractBeingDeployed: DeployedContract =
    contractService.getContract(contractName);

  console.log(`Contract being initialized: ${contractBeingDeployed.id}`)

  const tx = new ContractExecuteTransaction()
    .setContractId(contractBeingDeployed.id)
    .setGas(2000000)
    .setFunction(
      "initialize",
      new ContractFunctionParameters()
        .addAddress(`${addressOne}`)
        .addAddress(`${addressTwo}`)
        .addAddress(`${addressThree}`)
        .addAddress(`${addressFour}`)
    )

  const txExecute = await tx.execute(client);
  const txResponse = await txExecute.getRecord(client);
  console.log(txResponse);
}

main()
  .then((res) => console.log(res))
  .catch((error) => console.error(error))
  .finally(() => process.exit(1));