import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {ethers, upgrades} from "hardhat";
import {FeeProvider, GoldPriceOracle} from "../../typechain-types";
import { ethers as ethersOriginal } from "ethers";

/// Deploys all contracts
/// Sets the contract configs for each contract
export async function deployAllContracts(owner: SignerWithAddress, charlie: SignerWithAddress, dave: SignerWithAddress, company: SignerWithAddress) {
  const goldPriceFromMainnet = await getLatestGoldPriceMainnet();
  const goldPriceOracleContract = await ethers.getContractFactory("GoldPriceOracle");
  const goldPriceOracle = await goldPriceOracleContract.deploy(goldPriceFromMainnet.price);

  const feeProviderContract = await ethers.getContractFactory("FeeProvider");
  const feeProvider = await feeProviderContract.deploy();

  const goldTokenContract = await ethers.getContractFactory("GOLD");
  const goldToken = await upgrades.deployProxy(
    goldTokenContract,
    [goldPriceOracle.address],
    {initializer: 'initialize'}
  );

  const retrievalGuardList = [charlie.address, dave.address, owner.address];
  const gbarTokenContract = await ethers.getContractFactory("GBAR");
  const gbarToken = await upgrades.deployProxy(
    gbarTokenContract,
    [feeProvider.address, goldToken.address, goldPriceOracle.address, 3, retrievalGuardList],
    {initializer: 'initialize'}
  );

  const gbarVaultContract = await ethers.getContractFactory("GBARVault");
  const gbarVault = await upgrades.deployProxy(
    gbarVaultContract,
    [gbarToken.address],
    {initializer: 'initialize'}
  );

  const goldStakeVaultContract = await ethers.getContractFactory("GoldStakeVault");
  const goldStakeVault = await upgrades.deployProxy(
    goldStakeVaultContract,
    [goldToken.address, gbarToken.address],
    {initializer: 'initialize'}
  );

  const feeDistributorContract = await ethers.getContractFactory("FeeDistributor");
  const feeDistributor = await upgrades.deployProxy(
    feeDistributorContract,
    [gbarToken.address, goldStakeVault.address, company.address, goldPriceOracle.address],
    {initializer: 'initialize'}
  );

  const goldVaultContract= await ethers.getContractFactory("GoldVault");
  const goldVault = await upgrades.deployProxy(
    goldVaultContract,
    [goldToken.address],
    {initializer: 'initialize'}
  );

  await setContractConfigs(
    goldPriceOracle,
    feeProvider,
    goldToken,
    gbarToken,
    gbarVault,
    goldStakeVault,
    feeDistributor,
  );

  return {
    goldPriceOracle,
    feeProvider,
    goldToken,
    gbarToken,
    gbarVault,
    goldStakeVault,
    feeDistributor,
    retrievalGuardList,
    goldVault
  }
}

async function setContractConfigs(
  goldPriceOracle: GoldPriceOracle,
  feeProvider: FeeProvider,
  goldToken: any,
  gbarToken: any,
  gbarVault: any,
  goldStakeVault: any,
  feeDistributor: any
) {
  await gbarToken.setFeeDistributor(feeDistributor.address);
  await gbarToken.setGBARVault(gbarVault.address);
  await gbarToken.setGoldContract(goldToken.address);
  await gbarToken.addFeeExclusion(feeDistributor.address);
  await gbarToken.addFeeExclusion(gbarVault.address);
  await gbarToken.addFeeExclusion(goldStakeVault.address);
  await gbarToken.addFeeExclusion(goldToken.address); // not needed

  await goldToken.setGbarToken(gbarToken.address);
  await goldToken.setGoldStakeVault(goldStakeVault.address);
  await goldStakeVault.setFeeDistributor(feeDistributor.address);
}

export async function upgradeContract(contractName: string, address: string) {
  const contract = await ethers.getContractFactory(contractName);
  return await upgrades.upgradeProxy(address, contract);
}

export async function deployContract(contractName: string) {
  const contract = await ethers.getContractFactory(contractName);
  return await contract.deploy();
}

export async function getLatestGoldPriceMainnet() {
  const provider = new ethersOriginal.providers.JsonRpcProvider(`https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`);
  const contractAddress = '0x214ed9da11d2fbe465a6fc601a91e62ebec1a0d6';
  const abi = [
    'function latestRoundData() external view returns (\n' +
    '      uint80 roundId,\n' +
    '      int256 answer,\n' +
    '      uint256 startedAt,\n' +
    '      uint256 updatedAt,\n' +
    '      uint80 answeredInRound\n' +
    '    )'
  ];
  const contract = new ethersOriginal.Contract(contractAddress, abi, provider);
  const price = await contract.latestRoundData();
  const priceInDollars = price[1].toString() / 10**8;
  return {
    price: price[1],
    priceInDollars: priceInDollars
  }
}