const hre = require("hardhat");
const { ethers } = hre;

async function deployFNFTNestableERC1155() {
  const FNFTNestableERC1155 = await ethers.getContractFactory(
    "FNFTNestableERC1155"
  );
  const fnftNestableERC1155 = await FNFTNestableERC1155.deploy();
  await fnftNestableERC1155.deployed();
  console.log(
    `Deploy: NESTABLENFT_ERC1155_ADDRESS=${fnftNestableERC1155.address}`
  );
}

module.exports = deployFNFTNestableERC1155;

// Allow script to be run standalone
if (require.main === module) {
  deployFNFTNestableERC1155()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
