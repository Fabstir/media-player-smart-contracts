require("hardhat-abi-exporter");
require("@nomiclabs/hardhat-ethers");
require("@atixlabs/hardhat-time-n-mine");
require("dotenv").config();

module.exports = {
  networks: {
    hardhat: {
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: true,
      timeout: 1000000,
      // chainId: 1337,
    },
    polygon_mumbai: {
      url: "",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      chainId: 80001,
      gas: 8000000,
      blockGasLimit: 30000000,
      allowUnlimitedContractSize: true,
      timeout: 1000000,
    },
  },

  solidity: {
    version: "0.8.21", // Note that this only has the version number
    settings: {
      evmVersion: "berlin",
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
};
