import {DeployedContract} from "./model/contract";
import dotenv from "dotenv";
import {ContractService} from "./service/ContractService";
import {
  ContractCallQuery,
  ContractExecuteTransaction,
  ContractFunctionParameters,
  ContractFunctionResult
} from "@hashgraph/sdk";
import ClientManagement from "./utils/ClientManagement";
dotenv.config();
const {
  CONTRACT_NAME,
  HBAR_DEPLOYER_ACCOUNT_ID
} = process.env;

const contractService = new ContractService();
const clientManagement = new ClientManagement();

const client = clientManagement.createClientAsAdmin();
// const clientAttack = clientManagement.createClientAsAttack();

const feeProviderEvm = "0x000000000000000000000000000000000046277c"

async function main() {
  const goldFunctions = [
    "goldOracleAddress",
    "name",
    "owner",
  ];
  const goldType = [
    0,
    3,
    0
  ]
  await confirm("GOLD", goldFunctions, goldType);

  const gbarFunctions = [
    "FeeProvider",
    "GoldToken",
    "GoldOracle",
    "numConfirmationsRequired",
    "stabilizationTimestamp",
    "getRetrievalRequestCount",
    "getRetrievalRetrievalGuardsCount",
    "name",
    "owner"
  ];
  const gbarType = [
    0,
    0,
    0,
    1,
    2,
    2,
    2,
    3,
    0
  ]
  await confirm("GBAR", gbarFunctions, gbarType);

  const gbarVaultFunctions = [
    "GbarToken",
    "getContractBalance",
    "owner"
  ]
  const gbarVaultType = [
    0,
    2,
    0
  ]
  await confirm("GBARVault", gbarVaultFunctions, gbarVaultType);

  // next line results in revert
  // await initializeAgain("GOLD");
  return "Done";
}

async function confirm(contractName: string, functionNames: string[], type: number[]) {
  const contractBeingDeployed: DeployedContract =
    contractService.getContract(contractName);

  for(let i = 0; i < functionNames.length; i++) {
    const tx = new ContractCallQuery()
      .setContractId(contractBeingDeployed.id)
      .setGas(100000)
      .setFunction(
        functionNames[i]
      );

    const txExecuted: ContractFunctionResult = await tx.execute(client);
    let txResponse;
    if (type[i] === 0) {
      txResponse = txExecuted.getAddress(0);
    } else if (type[i] === 1) {
      txResponse = txExecuted.getInt8(0);
    } else if (type[i] === 2) {
      const bigNr = txExecuted.getUint256(0);
      txResponse = bigNr.toString();
      // txResponse = txExecuted.getUint256();
    } else if (type[i] === 3) {
      txResponse = txExecuted.getString(0);
    }
    console.log(txResponse);
  }
}

main()
  .then((res) => console.log(res))
  .catch((error) => console.error(error))
  .finally(() => process.exit(1));