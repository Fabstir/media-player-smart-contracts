const hre = require("hardhat");
const { ethers } = hre;

async function deployFNFTNestable() {
  const FNFTNestable = await ethers.getContractFactory("FNFTNestable");
  const fnftNestable = await FNFTNestable.deploy();
  await fnftNestable.deployed();
  console.log(`Deploy: NESTABLENFT_ADDRESS=${fnftNestable.address}`);
}

module.exports = deployFNFTNestable;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTNestable()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
