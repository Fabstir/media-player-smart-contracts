// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./FNFTMarketplaceTypes.sol";

// Define your interface
/**
 * @title IFNFTMarketplaceCreate
 * @dev Interface for the FNFT Marketplace Create functionality.
 *
 * This interface defines the functions related to the creation of market items in the FNFT Marketplace.
 * Implementing contracts must adhere to this interface to ensure compatibility with the marketplace.
 */
interface IFNFTMarketplaceCreate {
    /**
     * @dev Creates a new market item.
     * @param input The input data required to create a market item, encapsulated in a struct.
     *
     * Requirements:
     * - The caller must have the necessary permissions to create a market item.
     */
    function createMarketItem(
        FNFTMarketplaceTypes.MarketItemInput memory input
    ) external;

    /**
     * @dev Accepts pending market items.
     * @param itemIds An array of item IDs to be accepted.
     * @param amounts An array of amounts corresponding to each item ID.
     *
     * Requirements:
     * - The caller must have the necessary permissions to accept market items.
     */
    function acceptMarketItemsPending(
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external;

    /**
     * @dev Deletes pending market items.
     * @param itemIds An array of item IDs to be deleted.
     * @param amounts An array of amounts corresponding to each item ID.
     *
     * Requirements:
     * - The caller must have the necessary permissions to delete market items.
     */
    function deleteMarketItemsPending(
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external;

    /**
     * @dev Fetches all market items.
     * @return An array of market items.
     */
    function fetchMarketItems()
        external
        view
        returns (FNFTMarketplaceTypes.MarketItem[] memory);

    /**
     * @dev Fetches sold market items for a specific item ID.
     * @param itemId The unique identifier for the market item.
     * @return An array of sold market items.
     */
    function fetchMarketItemsSold(
        uint256 itemId
    ) external view returns (FNFTMarketplaceTypes.MarketItemSold[] memory);

    /**
     * @dev Fetches the NFTs bought by the caller.
     * @return An array of market items bought by the caller.
     */
    function fetchMyNFTsBought()
        external
        view
        returns (FNFTMarketplaceTypes.MarketItemSold[] memory);

    /**
     * @dev Checks if a market item is active.
     * @param itemId The unique identifier for the market item.
     * @return isMarketItemActive_ A boolean indicating whether the market item is active.
     *
     * Requirements:
     * - The function must be called with a valid item ID.
     */
    function isMarketItemActive(
        uint256 itemId
    ) external view returns (bool isMarketItemActive_);
}
