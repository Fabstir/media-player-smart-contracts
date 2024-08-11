const hre = require("hardhat");

const deployTipERC721 = require("./deploy_TipERC721");
const deployTipERC1155 = require("./deploy_TipERC1155");

const deployFNFTFactoryTipERC721 = require("./deploy_FNFTFactoryTipERC721");
const deployFNFTFactoryTipERC1155 = require("./deploy_FNFTFactoryTipERC1155");

const deployFNFTNestable = require("./deploy_FNFTNestable.js");
const deployFNFTNestableERC1155 = require("./deploy_FNFTNestableERC1155.js");

const deployFNFTFactoryABTToken = require("./deploy_FNFTFactoryABTToken");
const deployFNFTFactoryFNFTNestable = require("./deploy_FNFTFactoryFNFTNestable");
const deployFNFTFactoryFNFTNestableERC1155 = require("./deploy_FNFTFactoryFNFTNestableERC1155");

/**
 * Main function to deploy all necessary smart contracts.
 *
 * @async
 * @function main
 * @returns {Promise<void>} A promise that resolves when all deployments are complete.
 * @throws Will throw an error if any deployment fails.
 */
async function main() {
  let currencyContractAddresses = {};

  if (process.env.TEST_NETWORK === `hardhat`) {
    const [admin, account1, account2, account3] = await hre.ethers.getSigners();
    console.log("network = ", network);

    const account2Address = await account2.getAddress();
    const account3Address = await account3.getAddress();

    console.log("admin address:", await admin.getAddress());
    console.log("account2 address:", await account2.getAddress());
    console.log("account3 address:", await account3.getAddress());

    const SimpleToken = await hre.ethers.getContractFactory("SimpleToken");
    const usdcTokenHandle = await SimpleToken.deploy(
      "USD Coin",
      "USDC",
      6,
      "100000000000000000000000000"
    );
    await usdcTokenHandle.deployed();

    await usdcTokenHandle.transfer(account2Address, "100000000000");
    await usdcTokenHandle.transfer(account3Address, "100000000000");

    console.log("Deploy: USDC_TOKEN_ADDRESS=", usdcTokenHandle.address);

    currencyContractAddresses.USDC = usdcTokenHandle.address;
  } else {
    if (process.env.USDC_TOKEN_ADDRESS) {
      currencyContractAddresses.USDC = process.env.USDC_TOKEN_ADDRESS;
    }

    if (process.env.DAI_TOKEN_ADDRESS) {
      currencyContractAddresses.DAI = process.env.DAI_TOKEN_ADDRESS;
    }
  }

  // Deploy FNFTFactoryTipERC721
  await deployFNFTFactoryTipERC721();

  // Deploy FNFTFactoryTipERC1155
  await deployFNFTFactoryTipERC1155();

  await deployTipERC721();
  await deployTipERC1155();

  await deployFNFTNestable();

  await deployFNFTFactoryABTToken();

  // Nestable tokens
  await deployFNFTNestableERC1155();

  await deployFNFTFactoryFNFTNestable();
  await deployFNFTFactoryFNFTNestableERC1155();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
