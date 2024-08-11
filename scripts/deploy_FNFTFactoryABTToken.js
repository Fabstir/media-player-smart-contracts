const hre = require("hardhat");

const SUBSCRIPTION_PLATFORM_FEE_RATIO = 0.05;

/**
 * Deploys the FNFTFactoryABTToken smart contract.
 *
 * @async
 * @function deployFNFTFactoryABTToken
 * @returns {Promise<void>} A promise that resolves when the deployment is complete.
 * @throws Will throw an error if the deployment fails.
 */
async function deployFNFTFactoryABTToken() {
  require("dotenv").config();

  // FNFTFactoryABTToken
  const FNFTFactoryABTToken = await hre.ethers.getContractFactory(
    "FNFTFactoryABTToken"
  );
  const fnftFactoryABTToken = await FNFTFactoryABTToken.deploy();
  await fnftFactoryABTToken.deployed();

  console.log(
    `Deploy: FNFTFACTORY_ABT_TOKEN_ADDRESS=${fnftFactoryABTToken.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
module.exports = deployFNFTFactoryABTToken;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTFactoryABTToken()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
