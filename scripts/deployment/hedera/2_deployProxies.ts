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

import { main as deployContract } from "./logic";
import { main as createContractProxy } from "./transparentUpgradeableProxy";

async function main() {
  await deploy("GOLD", "artifacts/contracts/GOLD.sol/GOLD.json");
  await deploy("GoldVault", "artifacts/contracts/vaults/GoldVault.sol/GoldVault.json");
  await deploy("GBAR", "artifacts/contracts/GBAR.sol/GBAR.json");
  await deploy("GBARVault", "artifacts/contracts/vaults/GBARVault.sol/GBARVault.json");
  await deploy("GoldStakeVault", "artifacts/contracts/staking/GoldStakeVault.sol/GoldStakeVault.json");
  await deploy("FeeDistributor", "artifacts/contracts/staking/FeeDistributor.sol/FeeDistributor.json");

  return "Done";
}

async function deploy(contractName: string, path: string) {
  await deployContract(contractName, path);
  await createContractProxy(contractName);
}

main()
  .then((res) => console.log(res))
  .catch((error) => console.error(error))
  .finally(() => process.exit(1));