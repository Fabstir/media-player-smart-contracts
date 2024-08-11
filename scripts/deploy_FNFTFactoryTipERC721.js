const hre = require("hardhat");
const { ethers } = hre;

async function deployFNFTFactoryTipERC721() {
  const FNFTFactoryTipNFT = await ethers.getContractFactory(
    "FNFTFactoryTipERC721"
  );
  const fnftFactoryTipNFT = await FNFTFactoryTipNFT.deploy();
  await fnftFactoryTipNFT.deployed();

  console.log(
    `Deploy: FNFTFACTORY_TIPNFTERC721_ADDRESS=${fnftFactoryTipNFT.address}`
  );
}

module.exports = deployFNFTFactoryTipERC721;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTFactoryTipERC721()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
