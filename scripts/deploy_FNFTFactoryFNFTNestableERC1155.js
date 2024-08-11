const hre = require("hardhat");

const SUBSCRIPTION_PLATFORM_FEE_RATIO = 0.05;

/**
 * Deploys the FNFTFactoryFNFTNestableERC1155 smart contract.
 *
 * @async
 * @function deployFNFTFactoryFNFTNestableERC1155
 * @returns {Promise<void>} A promise that resolves when the deployment is complete.
 * @throws Will throw an error if the deployment fails.
 */
async function deployFNFTFactoryFNFTNestableERC1155() {
  require("dotenv").config();

  // FNFTFactoryFNFTNestableERC1155
  const FNFTFactoryFNFTNestableERC1155 = await hre.ethers.getContractFactory(
    "FNFTFactoryFNFTNestableERC1155"
  );
  const fnftFactoryFNFTNestableERC1155 =
    await FNFTFactoryFNFTNestableERC1155.deploy();
  await fnftFactoryFNFTNestableERC1155.deployed();

  console.log(
    `Deploy: FNFTFACTORY_FNFT_NESTABLE_ERC1155_ADDRESS=${fnftFactoryFNFTNestableERC1155.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
module.exports = deployFNFTFactoryFNFTNestableERC1155;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTFactoryFNFTNestableERC1155()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
