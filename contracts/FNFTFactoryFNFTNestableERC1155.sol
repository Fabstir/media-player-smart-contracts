// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./RMRK/nestable/FNFTNestableERC1155.sol";

/**
 * @title FNFTFactoryFNFTNestableERC1155
 * @dev FNFTFactoryFNFTNestableERC1155 is a factory contract for creating instances of FNFTNestableERC1155 contracts.
 * This contract provides functionality to deploy new FNFTNestableERC1155 contracts and manage their creation.
 *
 * @notice This contract is part of the FNFT (Fabstir Non-Fungible Token) system, which aims to enable fractional ownership and nesting of NFTs.
 */
contract FNFTFactoryFNFTNestableERC1155 {
    event FNFTNestableERC1155Created(address fnftNestableNFTAddress);

    /**
     * @notice Deploys a new FNFTNestable NFT
     */
    function deploy() external {
        FNFTNestableERC1155 fnftNestableERC1155 = new FNFTNestableERC1155();

        emit FNFTNestableERC1155Created(address(fnftNestableERC1155));
    }
}
