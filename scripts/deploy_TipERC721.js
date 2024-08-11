const hre = require("hardhat");
const { ethers } = hre;

/**
 * Deploys the TipERC721 smart contract.
 *
 * @async
 * @function deployTipERC721
 * @returns {Promise<void>} A promise that resolves when the deployment is complete.
 * @throws Will throw an error if the deployment fails.
 */
async function deployTipERC721() {
  const TipERC721 = await ethers.getContractFactory("TipERC721");
  const tipERC721 = await TipERC721.deploy();
  await tipERC721.deployed();
  await tipERC721.initialize("Fab NFT", "FBNFT1");

  console.log(`Deploy: TIPERC721_ADDRESS=${tipERC721.address}`);

  // Now let's call a function of the contract
  const name = await tipERC721.name(/* arguments */);
  console.log("tipERC721 Contract name:", name);

  // Test the name function right after deployment
  console.log("Contract name immediately:", await tipERC721.name());

  // Optionally, re-fetch the contract and test the name function
  const sameContract = await ethers.getContractAt(
    "TipERC721",
    tipERC721.address
  );
  console.log("Contract name after refetching:", await sameContract.name());
}

module.exports = deployTipERC721;

// Allow script to be run standalone
if (require.main === module) {
  deployTipERC721()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
