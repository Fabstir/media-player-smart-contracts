// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./ERC4973.sol";
import "./ERC4973Enumerable.sol";

/**
 * @title ABTToken
 * @dev ABTToken is a smart contract that implements the ERC4973 and ERC4973Enumerable standards.
 * This contract provides functionality for Account Bound Tokens (ABTs) with enumerable capabilities.
 *
 * Inherits from:
 * - ERC4973: Provides the core functionality for Account Bound Tokens (ABTs).
 * - ERC4973Enumerable: Extends ERC4973 to include enumeration capabilities for ABTs.
 *
 * @notice This contract is part of the ABT (Account Bound Token) system, which aims to provide unique, non-transferable tokens bound to user accounts.
 */
contract ABTToken is ERC4973, ERC4973Enumerable {
    constructor(
        string memory name,
        string memory symbol,
        address minter,
        address eoa
    ) ERC4973(name, symbol, "1.0", minter, eoa) {}

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC4973Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function getHash(
        address from,
        address to,
        string calldata tokenURI
    ) public view returns (bytes32) {
        return _getHash(from, to, tokenURI);
    }

    function mint(
        address to,
        uint256 tokenId,
        string calldata uri
    ) external returns (uint256) {
        return super._mint(to, tokenId, uri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC4973, ERC4973Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
