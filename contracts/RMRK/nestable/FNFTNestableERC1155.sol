// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "./RMRKNestableERC1155.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title FNFTNestableERC1155
 * @dev FNFTNestableERC1155 is a smart contract that extends the RMRKNestableERC1155 contract to provide additional functionality for NFTs (FNFTs).
 * This contract leverages the nestable capabilities of the RMRK protocol to allow FNFTs to be nested within other NFTs.
 *
 * Inherits from:
 * - RMRKNestableERC1155: Provides the core functionality for nestable ERC-1155 tokens as defined by the RMRK protocol.
 *
 * @notice This contract is part of the FNFT (Fabstir Non-Fungible Token) system, which aims to enable fractional ownership and nesting of NFTs.
 */
contract FNFTNestableERC1155 is RMRKNestableERC1155 {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    constructor() RMRKNestableERC1155() {}

    function mint(address recipient, uint256 amount) external returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _mint(recipient, newTokenId, amount, "");
        return newTokenId;
    }
}