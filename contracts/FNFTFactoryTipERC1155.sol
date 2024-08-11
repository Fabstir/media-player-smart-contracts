// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./micropayments/TipERC1155.sol";

/**
 * @title FNFTFactoryTipERC1155
 * @dev FNFTFactoryTipERC1155 is a factory contract for creating instances of FNFTTipERC1155 contracts.
 * This contract provides functionality to deploy new FNFTTipERC1155 contracts and manage their creation.
 *
 * @notice This contract is part of the FNFT (Fabstir Non-Fungible Token) system, which aims to enable
 * fractional ownership and tipping functionality for ERC-1155 tokens.
 */
contract FNFTFactoryTipERC1155 {
    event TipNFTCreated(address tipNFTAddress);

    /**
     * @notice Deploys a new Tip NFT
     */
    function deploy() external {
        TipERC1155 tipERC1155 = new TipERC1155();
        tipERC1155.initialize();

        emit TipNFTCreated(address(tipERC1155));
    }
}
