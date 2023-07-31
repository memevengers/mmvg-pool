import { ethers } from "hardhat";

async function main() {
  const pool = await ethers.deployContract("PoolV3", [
    "PoolV3Test",
    true,
    false,
    1690779600,
    86400,
    0,
    "0xEC3A0844Fa97Cc76bF613E66510938131d55AF8f",
    "0xEC3A0844Fa97Cc76bF613E66510938131d55AF8f",
  ]);

  await pool.waitForDeployment();
  console.log(`deployed to ${pool.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
