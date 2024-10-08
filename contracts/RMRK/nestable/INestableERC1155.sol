// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title INestableERC1155
 * @dev Interface for a nestable ERC1155 token, extending the IERC165 interface.
 */
interface INestableERC1155 is IERC165 {
    struct DirectOwner {
        uint256 tokenId;
        address ownerAddress;
    }

    event NestTransfer(
        address indexed from,
        address indexed to,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 indexed tokenId,
        uint256 amount
    );

    event ChildProposed(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId,
        uint256 amount
    );

    event ChildAccepted(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId,
        uint256 amount
    );

    event AllChildrenRejected(uint256 indexed tokenId);

    event ChildTransferred(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId,
        uint256 amount,
        bool fromPending,
        bool toZero
    );

    event OwnershipTransferred(uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner);

    struct Child {
        uint256 tokenId;
        address contractAddress;
        uint256 amount;
    }

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function directOwnerOf(uint256 tokenId) external view returns (address, uint256, bool);

    function burn(uint256 tokenId, uint256 amount, uint256 maxRecursiveBurns) external returns (uint256);

    function addChild(
        uint256 parentId,
        uint256 childId,
        bytes memory data
    ) external;

    function acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) external;

    function rejectAllChildren(uint256 tokenId, uint256 maxRejections) external;

    function transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bool isPending,
        bytes memory data
    ) external;

    function childrenOf(uint256 parentId) external view returns (Child[] memory);

    function pendingChildrenOf(uint256 parentId) external view returns (Child[] memory);

    function childOf(uint256 parentId, uint256 index) external view returns (Child memory);

    function pendingChildOf(uint256 parentId, uint256 index) external view returns (Child memory);

    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 destinationId,
        bytes memory data
    ) external;

    function transferOwnership(uint256 tokenId, address newOwner) external;
}