import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
import "solidity-coverage";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import * as dotenv from "dotenv";

dotenv.config();

const MAINNET_RPC_URL =
  process.env.MAINNET_RPC_URL  || "https://rinkeby.infura.io/v3/api-key"
const GOERLI_RPC_URL =
  process.env.GOERLI_RPC_URL || '"https://goerli.infura.io/v3/api-key"'

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"

// Your API key for Etherscan, obtain one at https://etherscan.io/
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Your etherscan API key"
const REPORT_GAS = process.env.REPORT_GAS || false

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: MAINNET_RPC_URL
      },
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      chainId: 5,
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      chainId: 1,
    },
  },
  solidity: "0.8.17",
  mocha: {
    timeout: 500000, // 500 seconds max for running tests
  }
};

export default config;
