/*-
 *
 * Hedera smart contract starter
 *
 * Copyright (C) 2023 Hedera Hashgraph, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import * as fs from "fs";
import { Contract, DeployedContract } from "../model/contract";
import { HttpRequest } from "../api/mirrorNodeRequest";

export class ContractService {
  private contractRecordFile = "./scripts/deployment/hedera/state/contracts.json";
  static DEV_CONTRACTS_PATH = "./scripts/deployment/hedera/state/contracts.json";

  constructor(filePath?: string) {
    this.contractRecordFile = filePath ?? ContractService.DEV_CONTRACTS_PATH;
  }

  private readFileContent = () => {
    const rawdata: Buffer = fs.readFileSync(this.contractRecordFile);
    return JSON.parse(String(rawdata)) as [DeployedContract];
  };

  public getContractId = async (contractEvmAddress: string): Promise<string> => {
    console.log(`Fetching contract id for evm address ${contractEvmAddress}`);
    const contract: Contract = await HttpRequest.send(contractEvmAddress, undefined);
    return contract.contract_id;
  };

  public saveDeployedContract = (
    contractId: string,
    contractAddress: string,
    contractName: string,
    calculatedHash: string
  ) => {

    if (contractName === "transparentUpgradeableProxy") {
      return;
    }

    const contracts: [DeployedContract] = this.readFileContent();

    console.log(`Contract id ${contractId}`);

    const newContract: DeployedContract = {
      name: contractName,
      id: contractId,
      address: "0x" + contractAddress,
      timestamp: new Date().toISOString(),
      hash: calculatedHash,
    };

    const contractsWithNewContract = [...contracts, newContract];

    const data = JSON.stringify(contractsWithNewContract, null, 4);

    console.log(`Contract details ${data}`);

    fs.writeFileSync(this.contractRecordFile, data);
  };

  public recordDeployedContract = async (
    contractAddress: string,
    contractName: string
  ) => {

    if (contractName === "transparentUpgradeableProxy") {
      return;
    }

    const contracts: [DeployedContract] = this.readFileContent();

    const contractId = await this.getContractId(contractAddress);
    console.log(`Contract id from api ${contractId}`);

    const newContract: DeployedContract = {
      name: contractName,
      id: contractId,
      address: contractAddress,
      timestamp: new Date().toISOString(),
      hash: ""
    };

    const contractsWithNewContract = [...contracts, newContract];

    const data = JSON.stringify(contractsWithNewContract, null, 4);

    console.log(`Contract details ${data}`);

    fs.writeFileSync(this.contractRecordFile, data);
  };

  public getAllContracts = (): Array<DeployedContract> =>
    this.readFileContent();

  public updateContractRecord = (
    updatedContract: DeployedContract,
    contractBeingDeployed: DeployedContract
  ) => {
    const contracts: Array<DeployedContract> = this.getAllContracts();
    const allOtherContracts = contracts.filter(
      (contract: DeployedContract) =>
        contract.address != contractBeingDeployed.address
    );

    const updatedContracts = [...allOtherContracts, updatedContract];

    const data = JSON.stringify(updatedContracts, null, 4);

    console.log(`Contract record updated ${data}`);

    fs.writeFileSync(this.contractRecordFile, data);
  };

  public getContract = (contractName: string): DeployedContract => {
    const contracts: Array<DeployedContract> = this.getAllContracts();
    const matchingContracts = contracts.filter(
      (contract: DeployedContract) => contract.name == contractName
    );
    const latestContract = matchingContracts[matchingContracts.length - 1];
    return latestContract;
  };

  public getContractWithProxy = (contractName: string): DeployedContract => {
    const contracts: Array<DeployedContract> = this.getAllContracts();
    const matchingProxyContracts = contracts.filter(
      (contract: DeployedContract) =>
        contract.name == contractName &&
        contract.transparentProxyAddress != null &&
        contract.transparentProxyId != null
    );
    return matchingProxyContracts[matchingProxyContracts.length - 1];
  };

  public getContractsWithProxy = (
    contractName: string,
    count: number
  ): DeployedContract[] => {
    const contracts: Array<DeployedContract> = this.getAllContracts();
    const matchingProxyContracts = contracts.filter(
      (contract: DeployedContract) =>
        contract.name == contractName &&
        contract.transparentProxyAddress != null &&
        contract.transparentProxyId != null
    );
    return matchingProxyContracts.slice(-count);
  };

  public getContractWithProxyById = (contractId: string): DeployedContract => {
    const contracts: Array<DeployedContract> = this.getAllContracts();
    const matchingProxyContracts = contracts.filter(
      (contract: DeployedContract) =>
        contract.transparentProxyAddress != null &&
        contract.transparentProxyId != null &&
        contract.transparentProxyId === contractId
    );
    return matchingProxyContracts[matchingProxyContracts.length - 1];
  };

  public addDeployed = (contract: DeployedContract) => {
    const contracts: [DeployedContract] = this.readFileContent();
    contracts.push(contract);
    const data = JSON.stringify(contracts, null, 4);
    fs.writeFileSync(this.contractRecordFile, data);
  };
}
