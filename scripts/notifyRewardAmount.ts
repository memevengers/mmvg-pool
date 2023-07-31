import { ethers } from "hardhat";

async function main() {
  const reward = ethers.parseEther("1000");
  const tokenAddress = "0xEC3A0844Fa97Cc76bF613E66510938131d55AF8f";
  const poolAddress = "0xf0c64fa22C9d3B145b0363C55bfb0252612baede";

  const token = await ethers.getContractAt("ERC20", tokenAddress);
  const pool = await ethers.getContractAt("PoolV3", poolAddress);

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
