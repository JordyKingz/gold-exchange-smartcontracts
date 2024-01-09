import {ethers} from "hardhat";
import {BigNumber} from "ethers";

let goldAddress: string;
let goldVaultAddress: string;
let gbarAddress: string;
let gbarVaultAddress: string;
let goldExchangeSwap: string;

goldAddress = process.env.GOLD_TOKEN || "";
goldVaultAddress = process.env.GOLD_VAULT || "";
gbarAddress = process.env.GBAR_TOKEN || "";
gbarVaultAddress = process.env.GBAR_VAULT || "";
goldExchangeSwap = process.env.GE_SWAP || "";

async function main() {
  const [
    owner,
  ] = await ethers.getSigners();
  try {
    const wallet = "0x6461891A9f6eE1e9a51a54D3A1738dF00204AFa3";
    // get balance of wallet
    const balance = await ethers.provider.getBalance(wallet);
    console.log("balance", balance.toString());

    const swapFactory = await ethers.getContractFactory("GoldExchangeSwapV2");
    const swapInstance = await swapFactory.attach(`${goldExchangeSwap}`);

    const ethGoldLiquidity = ethers.utils.parseEther("3.61259578");
    const goldLiquidity = ethers.utils.parseUnits("16", 0);

    // withdraw from vault
    const goldVaultFactory = await ethers.getContractFactory("GoldVault");
    const goldVaultInstance = await goldVaultFactory.attach(`${goldVaultAddress}`);
    // await withdrawFromVault(goldVaultInstance, owner.address, goldLiquidity);

    // approve GoldExchangeSwap
    const goldContract = await ethers.getContractFactory("GOLD");
    const goldInstance = await goldContract.attach(`${goldAddress}`);
    await goldInstance.approve(`${goldExchangeSwap}`, goldLiquidity);
    try {
      await swapInstance.addLiquidityETH(
        `${goldAddress}`,
        goldLiquidity,
        {value: ethGoldLiquidity, gasLimit: 3000000, from: owner.address});

      console.log("goldLiquidity added to GoldExchangeSwap");
    } catch(e) {
      console.log(e);
    }

    const ethGbarLiquidity = ethers.utils.parseEther("1.73682489");
    const gbarLiquidity = ethers.utils.parseUnits("500", 6);

    const gbarVaultFactory = await ethers.getContractFactory("GBARVault");
    const gbarVaultInstance = await gbarVaultFactory.attach(`${gbarVaultAddress}`);
    // await withdrawFromVault(gbarVaultInstance, owner.address, gbarLiquidity);
    // approve GoldExchangeSwap
    const gbarContract = await ethers.getContractFactory("GBAR");
    const gbarInstance = await gbarContract.attach(`${gbarAddress}`);
    await gbarInstance.approve(`${goldExchangeSwap}`, gbarLiquidity);
    try {
      await swapInstance.addLiquidityETH(
        `${gbarAddress}`,
        gbarLiquidity,
        {value: ethGbarLiquidity, gasLimit: 3000000, from: owner.address});

      console.log("gbarLiquidity added to GoldExchangeSwap");
    } catch (e) {
      console.log(e);
    }
  } catch(e) {
    console.log(e);
  }
}

async function withdrawFromVault(contract: any, to: string, amount: BigNumber) {
  try {
    await contract.withdrawTo(to, amount);
  } catch(e) {
    console.log(e);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
