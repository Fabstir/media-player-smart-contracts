require("hardhat-abi-exporter");
require("@nomiclabs/hardhat-ethers");
require("@atixlabs/hardhat-time-n-mine");
require("dotenv").config();

const accounts = {
  mnemonic: "test test test test test test test test test test test junk",
};

module.exports = {
  defaultNetwork: "localhost1",
  networks: {
    hardhat: {
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: false,
      timeout: 1000000,
      accounts: accounts,
      chainId: 1337,
    },
    localhost1: {
      url: "http://127.0.0.1:8546",
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: false,
      timeout: 1000000,
      accounts: accounts,
      chainId: 1337,
    },
    localhost2: {
      url: "http://127.0.0.1:8547",
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: false,
      timeout: 1000000,
      accounts: accounts,
      chainId: 1342,
    },
    polygon_mumbai: {
      url: process.env.POLYGON_AMOY_RPC_URL,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      chainId: 80001,
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: false,
      timeout: 1000000,
    },
    base_sepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      chainId: 84532,
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: false,
      timeout: 1000000,
    },
  },
  solidity: {
    version: "0.8.25",
    settings: {
      evmVersion: "shanghai",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  abiExporter: {
    path: "./build/contracts",
    clear: true,
    flat: true,
    spacing: 2,
    pretty: true,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    imports: ["node_modules"],
  },
};
