const hre = require("hardhat");
const { singletons } = require("@openzeppelin/test-helpers");
const { env, ethers } = hre;

async function main() {
  const [admin] = await ethers.getSigners();
  console.log("network = ", network);

  const TipERC721 = await ethers.getContractFactory("TipERC721");
  const tipERC721 = await TipERC721.deploy();
  await tipERC721.deployed();
  await tipERC721.initialize("Nestable NFT", "NNFT1");
  console.log(
    `Deploy: tipERC721 contract deployed at address `,
    tipERC721.address
  );

  const FNFTNestable = await ethers.getContractFactory("FNFTNestable");
  const fnftNestable = await FNFTNestable.deploy();
  await fnftNestable.deployed();
  console.log(
    `Deploy: fnftNestable contract deployed at address `,
    fnftNestable.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
