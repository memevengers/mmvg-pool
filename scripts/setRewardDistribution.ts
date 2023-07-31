import { ethers } from "hardhat";

async function main() {
  const poolAddress = "0xf0c64fa22C9d3B145b0363C55bfb0252612baede";
  const distridutionAddress = "0x1FB971960ADf0DF521ba1204b7E84b226649A43c";

  const pool = await ethers.getContractAt("PoolV3", poolAddress);
  await pool.setRewardDistribution(distridutionAddress);
  console.log(`setRewardDistribution ${distridutionAddress} to ${poolAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
