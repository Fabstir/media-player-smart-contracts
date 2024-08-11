// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "./RMRKNestable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title FNFTNestable
 * @dev FNFTNestable is a smart contract that extends the RMRKNestable contract to provide additional functionality for NFTs (FNFTs).
 * This contract leverages the nestable capabilities of the RMRK protocol to allow FNFTs to be nested within other NFTs.
 *
 * Inherits from:
 * - RMRKNestable: Provides the core functionality for nestable NFTs as defined by the RMRK protocol.
 *
 * @notice This contract is part of the FNFT (Fabstir Non-Fungible Token) system, which aims to enable fractional ownership and nesting of NFTs.
 */
contract FNFTNestable is RMRKNestable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function mint(address recipient) external returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _mint(recipient, newTokenId, "");
        return newTokenId;
    }
}
