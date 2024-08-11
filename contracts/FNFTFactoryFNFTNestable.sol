// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./RMRK/nestable/FNFTNestable.sol";

/**
 * @title FNFTFactoryFNFTNestable
 * @dev FNFTFactoryFNFTNestable is a factory contract for creating instances of FNFTNestable contracts.
 * This contract provides functionality to deploy new FNFTNestable contracts and manage their creation.
 *
 * @notice This contract is part of the FNFT (Fabstir Non-Fungible Token) system, which aims to enable fractional ownership and nesting of NFTs.
 */
contract FNFTFactoryFNFTNestable {
    event FNFTNestableCreated(address fnftNestableNFTAddress);

    /**
     * @notice Deploys a new FNFTNestable NFT
     */
    function deploy() external {
        FNFTNestable fnftNestable = new FNFTNestable();

        emit FNFTNestableCreated(address(fnftNestable));
    }
}
