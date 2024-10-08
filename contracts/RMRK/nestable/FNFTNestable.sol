// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "../../micropayments/TipERC721.sol";
import "./IERC7401.sol";
import "../core/RMRKCore.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../library/RMRKErrors.sol";

/**
 * @title FNFTNestable
 * @dev FNFTNestable is a smart contract that combines the functionality of RMRKNestable and TipERC721.
 * It implements the IERC7401 interface for nestable NFTs, inherits from TipERC721 for additional features,
 * and includes RMRKCore for RMRK-specific functionality.
 *
 * This contract allows for the creation of nestable NFTs with metadata, name, and symbol properties.
 * It also includes minting functionality and maintains compatibility with the ERC-721 standard.
 */
contract FNFTNestable is Initializable, TipERC721, IERC7401, RMRKCore {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Mapping from token ID to direct owner
    mapping(uint256 => DirectOwner) private _directOwners;

    // Mapping from token ID to list of active children
    mapping(uint256 => Child[]) private _activeChildren;

    // Mapping from token ID to list of pending children
    mapping(uint256 => Child[]) private _pendingChildren;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_
    ) public override initializer {
        // Call TipERC721's initialize function
        TipERC721.initialize(name_, symbol_);

        // Initialize FNFTNestable-specific components
        __FNFTNestable_init();
    }

    function __FNFTNestable_init() internal initializer {
        __FNFTNestable_init_unchained();
    }

    function __FNFTNestable_init_unchained() internal initializer {
        // Initialize any FNFTNestable specific state variables here
    }

    function mint(
        address recipient,
        string memory uri
    ) external returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, uri);
        return newTokenId;
    }

    // Implement IERC7401 functions

    function ownerOf(
        uint256 tokenId
    )
        public
        view
        virtual
        override(IERC721Upgradeable, ERC721Upgradeable, IERC7401)
        returns (address)
    {
        address owner = super.ownerOf(tokenId);
        uint256 parentId = _directOwners[tokenId].tokenId;
        while (parentId != 0) {
            owner = super.ownerOf(parentId);
            parentId = _directOwners[parentId].tokenId;
        }
        return owner;
    }

    function directOwnerOf(
        uint256 tokenId
    ) external view override returns (address, uint256, bool) {
        DirectOwner memory directOwner = _directOwners[tokenId];
        address owner = super.ownerOf(tokenId);

        if (directOwner.tokenId != 0) {
            // The token is owned by another token
            return (directOwner.ownerAddress, directOwner.tokenId, true);
        } else {
            // The token is owned by an EOA
            return (owner, 0, false);
        }
    }

    function burn(
        uint256 tokenId,
        uint256 maxRecursiveBurns
    ) external override returns (uint256) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );

        uint256 burnedChildren = 0;
        Child[] memory activeChildren = _activeChildren[tokenId];

        for (
            uint256 i = 0;
            i < activeChildren.length && burnedChildren < maxRecursiveBurns;
            i++
        ) {
            Child memory child = activeChildren[i];
            FNFTNestable childContract = FNFTNestable(child.contractAddress);
            burnedChildren += childContract.burn(
                child.tokenId,
                maxRecursiveBurns - burnedChildren
            );
        }

        delete _activeChildren[tokenId];
        delete _pendingChildren[tokenId];
        _burn(tokenId);

        return burnedChildren + 1;
    }

    function addChild(
        uint256 parentId,
        uint256 childId,
        bytes memory data
    ) external override {
        require(_exists(parentId), "ERC721: parent token does not exist");
        require(
            ownerOf(childId) == address(this),
            "Child token must be owned by this contract"
        );

        Child memory child = Child({
            tokenId: childId,
            contractAddress: msg.sender
        });

        _pendingChildren[parentId].push(child);

        emit ChildProposed(
            parentId,
            _pendingChildren[parentId].length - 1,
            msg.sender,
            childId
        );
    }

    function addChildNFT(
        uint256 parentId,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) public virtual {
        require(_exists(parentId), "FNFTNestable: parent token does not exist");
        require(
            ownerOf(parentId) == _msgSender(),
            "FNFTNestable: caller is not the owner of the parent token"
        );

        if (IERC721(childAddress).ownerOf(childId) != _msgSender()) {
            revert("FNFTNestable: caller is not the owner of the child token");
        }

        // Transfer ownership of child token to this contract
        IERC721(childAddress).transferFrom(
            _msgSender(),
            address(this),
            childId
        );

        Child memory child = Child({
            tokenId: childId,
            contractAddress: childAddress
        });

        uint256 length = _pendingChildren[parentId].length;

        if (length >= 128) {
            revert("FNFTNestable: maximum number of pending children reached");
        }

        _pendingChildren[parentId].push(child);

        // Previous length matches the index for the new child
        emit ChildProposed(parentId, length, childAddress, childId);
    }

    function acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) external override {
        require(
            _isApprovedOrOwner(_msgSender(), parentId),
            "ERC721: caller is not token owner or approved"
        );
        require(
            childIndex < _pendingChildren[parentId].length,
            "Child index out of bounds"
        );
        require(
            _pendingChildren[parentId][childIndex].contractAddress ==
                childAddress,
            "Child address mismatch"
        );
        require(
            _pendingChildren[parentId][childIndex].tokenId == childId,
            "Child ID mismatch"
        );

        Child memory child = _pendingChildren[parentId][childIndex];
        _activeChildren[parentId].push(child);

        _pendingChildren[parentId][childIndex] = _pendingChildren[parentId][
            _pendingChildren[parentId].length - 1
        ];
        _pendingChildren[parentId].pop();

        emit ChildAccepted(
            parentId,
            _activeChildren[parentId].length - 1,
            childAddress,
            childId
        );
    }

    function rejectAllChildren(
        uint256 parentId,
        uint256 maxRejections
    ) external override {
        require(
            _isApprovedOrOwner(_msgSender(), parentId),
            "ERC721: caller is not token owner or approved"
        );

        uint256 rejections = _pendingChildren[parentId].length < maxRejections
            ? _pendingChildren[parentId].length
            : maxRejections;

        for (uint256 i = 0; i < rejections; i++) {
            _pendingChildren[parentId].pop();
        }

        emit AllChildrenRejected(parentId);
    }

    function transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bool isPending,
        bytes memory data
    ) external override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );

        Child[] storage childrenArray = isPending
            ? _pendingChildren[tokenId]
            : _activeChildren[tokenId];
        require(childIndex < childrenArray.length, "Child index out of bounds");
        require(
            childrenArray[childIndex].contractAddress == childAddress,
            "Child address mismatch"
        );
        require(
            childrenArray[childIndex].tokenId == childId,
            "Child ID mismatch"
        );

        childrenArray[childIndex] = childrenArray[childrenArray.length - 1];
        childrenArray.pop();

        if (to == address(0)) {
            // Transfer to zero address (burn)
            FNFTNestable(childAddress).burn(childId, 0);
        } else if (destinationId == 0) {
            // Transfer to an EOA
            FNFTNestable(childAddress).safeTransferFrom(
                address(this),
                to,
                childId,
                data
            );
        } else {
            // Transfer to another token
            FNFTNestable(childAddress).nestTransferFrom(
                address(this),
                to,
                childId,
                destinationId,
                data
            );
        }

        emit ChildTransferred(
            tokenId,
            childIndex,
            childAddress,
            childId,
            isPending,
            to == address(0)
        );
    }

    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 destinationId,
        bytes memory data
    ) external override {
        address rootOwner = ownerOf(tokenId);
        require(
            _isApprovedOrOwner(_msgSender(), tokenId) || rootOwner == from,
            "ERC721: transfer caller is not owner nor approved"
        );

        uint256 fromTokenId = _directOwners[tokenId].tokenId;

        safeTransferFrom(from, to, tokenId, data);

        if (destinationId != 0) {
            // If destinationId is not 0, we are nesting the token
            _directOwners[tokenId] = DirectOwner({
                tokenId: destinationId,
                ownerAddress: to
            });
        } else {
            // If destinationId is 0, we are transferring to an EOA, so clear the DirectOwner
            delete _directOwners[tokenId];
        }

        emit NestTransfer(from, to, fromTokenId, destinationId, tokenId);
    }

    function childrenOf(
        uint256 parentId
    ) external view override returns (Child[] memory) {
        return _activeChildren[parentId];
    }

    function pendingChildrenOf(
        uint256 parentId
    ) external view override returns (Child[] memory) {
        return _pendingChildren[parentId];
    }

    function childOf(
        uint256 parentId,
        uint256 index
    ) external view override returns (Child memory) {
        require(
            index < _activeChildren[parentId].length,
            "Child index out of bounds"
        );
        return _activeChildren[parentId][index];
    }

    function pendingChildOf(
        uint256 parentId,
        uint256 index
    ) external view override returns (Child memory) {
        require(
            index < _pendingChildren[parentId].length,
            "Pending child index out of bounds"
        );
        return _pendingChildren[parentId][index];
    }

    // Override necessary functions from TipERC721 if needed

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(TipERC721, IERC165) returns (bool) {
        return
            interfaceId == type(IERC7401).interfaceId ||
            interfaceId == RMRK_INTERFACE ||
            super.supportsInterface(interfaceId);
    }
}
