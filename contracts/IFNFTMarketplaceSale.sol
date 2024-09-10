// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./FNFTMarketplaceTypes.sol";

// Define your interface
/**
 * @title IFNFTMarketplaceSale
 * @dev Interface for the FNFT Marketplace Sale functionality.
 *
 * This interface defines the functions related to the sale of market items in the FNFT Marketplace.
 * Implementing contracts must adhere to this interface to ensure compatibility with the marketplace.
 */
interface IFNFTMarketplaceSale {
    /**
     * @dev Creates a market sale for a specified item.
     * @param itemId The unique identifier for the market item.
     * @param fnftToken_ The address of the FNFT token contract.
     * @param value The value of the sale.
     * @param reseller The address of the reseller.
     * @return The unique identifier for the market item.
     *
     * Requirements:
     * - The function must be marked as payable to accept Ether.
     */
    function createMarketSale(
        uint256 itemId,
        address fnftToken_,
        uint256 value,
        address reseller
    ) external payable returns (uint256);
    function makeMarketSale(
        uint256 itemId,
        address fnftToken_
    ) external payable;
}
