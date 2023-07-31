import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import fs from "fs";
const privateKey = fs.readFileSync(".secret.main").toString().trim();

const config: HardhatUserConfig = {
  solidity: "0.5.16",
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://ethereum-sepolia.blockpi.network/v1/rpc/public",
      chainId: 11155111,
      gasPrice: "auto",
      accounts: [privateKey],
    },
  },
};

export default config;
