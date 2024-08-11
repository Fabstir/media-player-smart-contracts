const hre = require("hardhat");

const SUBSCRIPTION_PLATFORM_FEE_RATIO = 0.05;

async function deployFNFTFactoryFNFTNestable() {
  require("dotenv").config();

  /**
   * Deploys the FNFTFactoryFNFTNestable smart contract.
   *
   * @async
   * @function deployFNFTFactoryFNFTNestable
   * @returns {Promise<void>} A promise that resolves when the deployment is complete.
   * @throws Will throw an error if the deployment fails.
   */
  const FNFTFactoryFNFTNestable = await hre.ethers.getContractFactory(
    "FNFTFactoryFNFTNestable"
  );
  const fnftFactoryFNFTNestable = await FNFTFactoryFNFTNestable.deploy();
  await fnftFactoryFNFTNestable.deployed();

  console.log(
    `Deploy: FNFTFACTORY_FNFT_NESTABLE_ADDRESS=${fnftFactoryFNFTNestable.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
module.exports = deployFNFTFactoryFNFTNestable;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTFactoryFNFTNestable()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
