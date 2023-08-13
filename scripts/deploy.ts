import { ethers } from "hardhat";

async function main() {
  const distridutionAddress = "0x1FB971960ADf0DF521ba1204b7E84b226649A43c";
  const tokenAddress = "0xEC3A0844Fa97Cc76bF613E66510938131d55AF8f";
  const token = await ethers.getContractAt("ERC20", tokenAddress);
  const reward = ethers.parseEther("1000");

  // Deploy
  const pool = await ethers.deployContract("PoolV3", [
    "PoolV3Test",
    true,
    false,
    Math.floor(Date.now() / 1000),
    86400,
    0,
    tokenAddress,
    tokenAddress,
  ]);
  await pool.waitForDeployment();
  const poolAddress = pool.target;
  console.log(`deployed to ${poolAddress}`);

  // setRewardDistribution
  await pool.setRewardDistribution(distridutionAddress);
  console.log(`setRewardDistribution ${distridutionAddress} to ${poolAddress}`);

  // notifyRewardAmount
  await token.approve(poolAddress, reward);
  await pool.notifyRewardAmount(reward);
  console.log(
    `notifyRewardAmount ${ethers.formatEther(reward)} to ${poolAddress}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
