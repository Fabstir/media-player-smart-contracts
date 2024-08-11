// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./micropayments/TipERC721.sol";

/**
 * @title FNFTFactoryTipERC721
 * @dev A factory contract for creating ERC721 tokens with tipping functionality.
 */
contract FNFTFactoryTipERC721 {
    event TipNFTCreated(address tipNFTAddress);

    /**
     * @notice Deploys a new Tip NFT
     */
    function deploy(string memory name, string memory symbol) external {
        TipERC721 tipERC721 = new TipERC721();
        tipERC721.initialize(name, symbol);

        emit TipNFTCreated(address(tipERC721));
    }
}
