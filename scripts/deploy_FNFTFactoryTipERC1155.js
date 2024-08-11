const hre = require("hardhat");
const { ethers } = hre;

/**
 * Deploys the FNFTFactoryTipERC1155 smart contract.
 *
 * @async
 * @function deployFNFTFactoryTipERC1155
 * @returns {Promise<void>} A promise that resolves when the deployment is complete.
 * @throws Will throw an error if the deployment fails.
 */
async function deployFNFTFactoryTipERC1155() {
  const FNFTFactoryTipNFT = await ethers.getContractFactory(
    "FNFTFactoryTipERC1155"
  );
  const fnftFactoryTipNFT = await FNFTFactoryTipNFT.deploy();
  await fnftFactoryTipNFT.deployed();

  console.log(
    `Deploy: FNFTFACTORY_TIPNFTERC1155_ADDRESS=${fnftFactoryTipNFT.address}`
  );
}

module.exports = deployFNFTFactoryTipERC1155;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTFactoryTipERC1155()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
