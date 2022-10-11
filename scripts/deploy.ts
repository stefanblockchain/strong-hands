import { ethers, network } from "hardhat";
import helperConfig from "../helper-hardhat-config";
import verify from '../utils/verify';

async function main() {
  const name = network.name;
  const networkConf = helperConfig.networkConfig.find(el => el.name === network.name);
  const waitBlockConfirmations = 5;

  const feeStrategyArgs: any = [];
  const feeStrategyV1 = await (await ethers.getContractFactory("FeeStrategyV1", feeStrategyArgs)).deploy(...feeStrategyArgs);
  await feeStrategyV1.deployTransaction.wait(waitBlockConfirmations);

  console.log(`Deployed contract FeeStrategyV1 on : ${feeStrategyV1.address} address`);
  console.log(` FeeStrategyV1 args : ${feeStrategyArgs}`);

  const strongHandArgs: [number, string, string, string, string] = [networkConf!.lockTime!, networkConf!.poolAddressesProvider!, networkConf!.weithAToken!, feeStrategyV1.address, networkConf!.wethAddress!];
  const StrongHand = await ethers.getContractFactory("StrongHand");
  const strongHand = await StrongHand.deploy(...strongHandArgs);
  await strongHand.deployTransaction.wait(waitBlockConfirmations);

  console.log(`Deployed contract StrongHand on : ${strongHand.address} address`);
  console.log(` StrongHand args : ${strongHandArgs}`);

  if (!helperConfig.developmentChains.includes(name) && process.env.ETHERSCAN_API_KEY) {
    await verify(feeStrategyV1.address, feeStrategyArgs);
    await verify(strongHand.address, strongHandArgs);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
