// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { singletons } = require("@openzeppelin/test-helpers");
const { env, ethers } = hre;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

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
