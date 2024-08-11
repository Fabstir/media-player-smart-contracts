const hre = require("hardhat");
const { ethers } = hre;

async function deployTipERC1155() {
  const TipERC1155 = await ethers.getContractFactory("TipERC1155");
  const tipERC1155 = await TipERC1155.deploy();
  await tipERC1155.deployed();
  await tipERC1155.initialize();

  console.log(`Deploy: TIPERC1155_ADDRESS=${tipERC1155.address}`);
}

module.exports = deployTipERC1155;

// Allow script to be run standalone
if (require.main === module) {
  deployTipERC1155()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
