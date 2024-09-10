// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title FNFTMarketplaceTypes
 * @dev Library for defining types used in the FNFT Marketplace.
 *
 * This library contains the struct definitions and events used across the FNFT Marketplace.
 * It helps in maintaining a consistent set of types and events that can be reused in various contracts.
 */
library FNFTMarketplaceTypes {
    /**
     * @dev Struct representing a market item.
     * @param itemId The unique identifier for the market item.
     * @param fnftToken The address of the FNFT token contract.
     * @param tokenId The unique identifier for the token within the FNFT token contract.
     * @param seller The address of the seller.
     * @param creator The address of the creator.
     * @param baseToken The address of the base token used for transactions.
     * @param amount The amount of tokens for sale.
     * @param startPrice The starting price of the market item.
     * @param reservePrice The reserve price of the market item.
     * @param startTime The start time of the market item sale.
     * @param endTime The end time of the market item sale.
     * @param cancelTime The time when the market item was cancelled.
     * @param resellerFeeRatio The fee ratio for resellers.
     * @param holders The addresses of the holders.
     * @param holdersRatio The ratio of the holders.
     * @param fabstir The address of the Fabstir platform.
     * @param platform The address of the platform.
     * @param fabstirFeeRatio The fee ratio for Fabstir.
     * @param platformFeeRatio The fee ratio for the platform.
     * @param creatorFeeRatio The fee ratio for the creator.
     * @param data Additional data related to the market item.
     * @param isCancelled Boolean indicating if the market item is cancelled.
     */
    struct MarketItem {
        uint256 itemId;
        address fnftToken;
        uint256 tokenId;
        address seller;
        address creator;
        address baseToken;
        uint256 amount;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        uint256 cancelTime;
        uint256 resellerFeeRatio;
        address[] holders;
        uint256[] holdersRatio;
        address fabstir;
        address platform;
        uint256 fabstirFeeRatio;
        uint256 platformFeeRatio;
        uint256 creatorFeeRatio;
        string data;
        bool isCancelled;
    }

    /**
     * @dev Struct representing the input for creating a market item.
     * @param itemId The unique identifier for the market item.
     * @param tokenId The unique identifier for the token within the FNFT token contract.
     * @param seller The address of the seller.
     * @param fnftToken The address of the FNFT token contract.
     * @param baseToken The address of the base token used for transactions.
     * @param amount The amount of tokens for sale.
     * @param startPrice The starting price of the market item.
     * @param reservePrice The reserve price of the market item.
     * @param startTime The start time of the market item sale.
     * @param endTime The end time of the market item sale.
     * @param cancelTime The time when the market item was cancelled.
     * @param resellerFeeRatio The fee ratio for resellers.
     * @param creator The address of the creator.
     * @param creatorFeeRatio The fee ratio for the creator.
     * @param holders The addresses of the holders.
     * @param holdersRatio The ratio of the holders.
     * @param data Additional data related to the market item.
     */
    struct MarketItemInput {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address fnftToken;
        address baseToken;
        uint256 amount;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        uint256 cancelTime;
        uint256 resellerFeeRatio;
        address creator;
        uint256 creatorFeeRatio;
        address[] holders;
        uint256[] holdersRatio;
        string data;
    }

    /**
     * @dev Struct representing a sold market item.
     * @param itemId The unique identifier for the market item.
     * @param fnftToken The address of the FNFT token contract.
     * @param baseToken The address of the base token used for transactions.
     * @param tokenId The unique identifier for the token within the FNFT token contract.
     * @param seller The address of the seller.
     * @param buyer The address of the buyer.
     * @param price The price at which the market item was sold.
     * @param amount The amount of tokens sold.
     * @param timeStamp The timestamp when the market item was sold.
     * @param reseller The address of the reseller.
     * @param isFNFTTokenPending Boolean indicating if the FNFT token is pending.
     */
    struct MarketItemSold {
        uint256 itemId;
        address fnftToken;
        address baseToken;
        uint256 tokenId;
        address seller;
        address buyer;
        uint256 price;
        uint256 amount;
        uint256 timeStamp;
        address reseller;
        bool isFNFTTokenPending;
    }

    /**
     * @dev Event emitted when a market item is created.
     * @param itemId The unique identifier for the market item.
     * @param fnftToken The address of the FNFT token contract.
     * @param tokenId The unique identifier for the token within the FNFT token contract.
     * @param marketItem_ The market item that was created.
     */
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed fnftToken,
        uint256 indexed tokenId,
        MarketItem marketItem_
    );

    /**
     * @dev Enum representing the status of a market item.
     * @param Accepted The market item is accepted.
     * @param Pending The market item is pending.
     * @param Rejected The market item is rejected.
     * @param Deleted The market item is deleted.
     * @param Cancelled The market item is cancelled.
     * @param Removed The market item is removed.
     * @param Sold The market item is sold.
     */
    enum MarketItemStatus {
        Accepted,
        Pending,
        Rejected,
        Deleted,
        Cancelled,
        Removed,
        Sold
    }

    /**
     * @dev Emitted when the status of a market item changes.
     * @param itemId The unique identifier for the market item.
     * @param changedBy The address of the user who changed the status.
     * @param status The new status of the market item.
     * @param amount The amount associated with the status change.
     *
     * This event is emitted whenever the status of a market item is updated.
     * It helps in tracking the lifecycle and status changes of a market item within the marketplace.
     */
    event MarketItemStatusChanged(
        uint256 indexed itemId,
        address indexed changedBy,
        FNFTMarketplaceTypes.MarketItemStatus indexed status,
        uint256 amount
    );

    /**
     * @dev Emitted when a market item is sold.
     * @param itemId The unique identifier for the market item.
     * @param fnftToken The address of the FNFT token contract.
     * @param tokenId The unique identifier for the token within the FNFT token contract.
     * @param MarketItemSold_ The details of the sold market item, encapsulated in a struct.
     *
     * This event is emitted whenever a market item is successfully sold.
     * It provides information about the sale, including the item ID, token contract address, token ID, and details of the sold item.
     */
    event MarketItemSoldEvent(
        uint256 indexed itemId,
        address indexed fnftToken,
        uint256 indexed tokenId,
        MarketItemSold MarketItemSold_
    );
}
