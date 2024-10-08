// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "../../micropayments/TipERC1155.sol";
import "./INestableERC1155.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../library/RMRKErrors.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FNFTNestableERC1155 is Initializable, TipERC1155, INestableERC1155 {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using Address for address;

    CountersUpgradeable.Counter private _tokenIdCounter;

    // Mapping from token ID to direct owner
    mapping(uint256 => DirectOwner) private _RMRKOwners;

    // Mapping from token ID to array of active children structs
    mapping(uint256 => Child[]) internal _activeChildren;

    // Mapping from token ID to array of pending children structs
    mapping(uint256 => Child[]) internal _pendingChildren;

    // Mapping of child token address to child token ID to whether they are pending or active on any token
    mapping(address => mapping(uint256 => uint256)) internal _childIsInActive;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        TipERC1155.initialize();
        __FNFTNestableERC1155_init();
        __ReentrancyGuard_init();
    }

    function __FNFTNestableERC1155_init() internal initializer {
        __FNFTNestableERC1155_init_unchained();
    }

    function __FNFTNestableERC1155_init_unchained() internal initializer {
        // Initialize any FNFTNestableERC1155 specific state variables here
    }

    function mintToken(
        address account,
        uint256 tokenId,
        string memory tokenURI,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (uint256) {
        uint256 newTokenId = TipERC1155.mintToken(
            account,
            tokenId,
            tokenURI,
            amount,
            data
        );
        return newTokenId;
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        (address owner, uint256 ownerTokenId, bool isNft) = directOwnerOf(
            tokenId
        );
        if (isNft) {
            owner = INestableERC1155(owner).ownerOf(ownerTokenId);
        }
        return owner;
    }

    function directOwnerOf(
        uint256 tokenId
    ) public view override returns (address, uint256, bool) {
        DirectOwner memory owner = _RMRKOwners[tokenId];
        if (owner.ownerAddress == address(0)) revert RMRKPartDoesNotExist();
        return (owner.ownerAddress, owner.tokenId, owner.tokenId != 0);
    }

    function addChild(
        uint256 parentId,
        uint256 childId,
        bytes memory data
    ) public override {
        require(_exists(parentId), "ERC1155: parent token does not exist");
        address childAddress = _msgSender();
        require(childAddress != address(this), "Cannot add child to self");

        uint256 parentBalance = balanceOf(_msgSender(), parentId);
        require(parentBalance > 0, "Not owner of parent token");

        uint256 childBalance = IERC1155(childAddress).balanceOf(
            _msgSender(),
            childId
        );
        require(childBalance >= parentBalance, "Insufficient child balance");

        Child memory child = Child({
            tokenId: childId,
            contractAddress: childAddress,
            amount: parentBalance
        });

        _addChild(parentId, child, data);
    }

    function addChildNFT(
        uint256 parentId,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) public virtual {
        if (!_exists(parentId)) revert RMRKTokenDoesNotHaveAsset();

        uint256 parentBalance = balanceOf(_msgSender(), parentId);
        if (parentBalance == 0) revert RMRKInsufficientParentBalance();

        uint256 childBalance = IERC1155(childAddress).balanceOf(
            _msgSender(),
            childId
        );
        if (childBalance < parentBalance) revert RMRKInsufficientChildBalance();

        IERC1155(childAddress).safeTransferFrom(
            _msgSender(),
            address(this),
            childId,
            parentBalance,
            data
        );

        Child memory child = Child({
            tokenId: childId,
            contractAddress: childAddress,
            amount: parentBalance
        });

        _addChild(parentId, child, data);
    }

    function acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) public override {
        require(
            _isApprovedOrOwner(_msgSender(), parentId),
            "ERC1155: caller is not owner nor approved"
        );
        Child memory child = pendingChildOf(parentId, childIndex);
        require(
            child.contractAddress == childAddress && child.tokenId == childId,
            "Child does not match"
        );

        _acceptChild(parentId, childIndex, childAddress, childId);
    }

    function rejectAllChildren(
        uint256 parentId,
        uint256 maxRejections
    ) public override {
        require(
            _isApprovedOrOwner(_msgSender(), parentId),
            "ERC1155: caller is not owner nor approved"
        );

        uint256 pendingChildren = _pendingChildren[parentId].length;
        if (pendingChildren > maxRejections) {
            revert RMRKUnexpectedNumberOfChildren();
        }

        for (uint256 i = pendingChildren; i > 0; i--) {
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
    ) public override nonReentrant {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC1155: caller is not owner nor approved"
        );

        Child[] storage childrenArray = isPending
            ? _pendingChildren[tokenId]
            : _activeChildren[tokenId];
        require(childIndex < childrenArray.length, "Child index out of bounds");
        require(
            childrenArray[childIndex].contractAddress == childAddress,
            "Wrong child address"
        );
        require(
            childrenArray[childIndex].tokenId == childId,
            "Wrong child token ID"
        );

        uint256 amount = balanceOf(_msgSender(), tokenId);

        if (to == address(0) && destinationId != 0) {
            revert("Cannot burn nested tokens directly");
        }

        if (isPending) {
            _transferPendingChild(
                tokenId,
                to,
                destinationId,
                childIndex,
                childAddress,
                childId,
                amount,
                data
            );
        } else {
            _transferActiveChild(
                tokenId,
                to,
                destinationId,
                childIndex,
                childAddress,
                childId,
                amount,
                data
            );
        }
    }

    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 destinationId,
        bytes memory data
    ) public override nonReentrant {
        safeTransferFrom(from, to, tokenId, amount, data);

        if (destinationId != 0) {
            _RMRKOwners[tokenId] = DirectOwner({
                ownerAddress: to,
                tokenId: destinationId
            });
        } else {
            delete _RMRKOwners[tokenId];
        }

        emit NestTransfer(from, to, 0, destinationId, tokenId, amount);
    }

    function childrenOf(
        uint256 parentId
    ) public view override returns (Child[] memory) {
        return _activeChildren[parentId];
    }

    function pendingChildrenOf(
        uint256 parentId
    ) public view override returns (Child[] memory) {
        return _pendingChildren[parentId];
    }

    function childOf(
        uint256 parentId,
        uint256 index
    ) public view override returns (Child memory) {
        if (index >= _activeChildren[parentId].length)
            revert RMRKChildIndexOutOfRange();
        return _activeChildren[parentId][index];
    }

    function pendingChildOf(
        uint256 parentId,
        uint256 index
    ) public view override returns (Child memory) {
        if (index >= _pendingChildren[parentId].length)
            revert RMRKPendingChildIndexOutOfRange();
        return _pendingChildren[parentId][index];
    }

    function transferOwnership(
        uint256 tokenId,
        address newOwner
    ) external override {
        address sender = _msgSender();
        (address currentOwner, uint256 parentId, bool isNft) = directOwnerOf(
            tokenId
        );

        // Check if the sender is the owner or approved
        require(
            _isApprovedOrDirectOwner(sender, tokenId),
            "FNFTNestableERC1155: transfer caller is not owner nor approved"
        );

        // Check that the new owner is not the zero address
        require(
            newOwner != address(0),
            "FNFTNestableERC1155: new owner is the zero address"
        );

        // Check that the new owner is not the current owner
        require(
            currentOwner != newOwner,
            "FNFTNestableERC1155: new owner is the current owner"
        );

        // Update the owner in the RMRK ownership structure
        _RMRKOwners[tokenId] = DirectOwner({
            ownerAddress: newOwner,
            tokenId: 0 // Reset to 0 as it's now owned by an address, not a token
        });

        // Emit the OwnershipTransferred event
        emit OwnershipTransferred(tokenId, currentOwner, newOwner);
    }

    // Helper function to check if the caller is approved or direct owner
    function _isApprovedOrDirectOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        (address owner, uint256 parentId, ) = directOwnerOf(tokenId);
        // When the parent is an NFT, only it can do operations
        if (parentId != 0) {
            return (spender == owner);
        }
        // Otherwise, the owner or approved address can
        return (spender == owner || isApprovedForAll(owner, spender));
    }

    function _transferPendingChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        uint256 amount,
        bytes memory data
    ) internal {
        Child storage child = _pendingChildren[tokenId][childIndex];

        if (to == address(0)) {
            _removeChildByIndex(_pendingChildren[tokenId], childIndex);
            INestableERC1155(childAddress).burn(childId, amount, 0);
        } else if (destinationId == 0) {
            _removeChildByIndex(_pendingChildren[tokenId], childIndex);
            IERC1155(childAddress).safeTransferFrom(
                address(this),
                to,
                childId,
                amount,
                data
            );
        } else {
            _removeChildByIndex(_pendingChildren[tokenId], childIndex);
            INestableERC1155(childAddress).nestTransferFrom(
                address(this),
                to,
                childId,
                amount,
                destinationId,
                data
            );
        }

        emit ChildTransferred(
            tokenId,
            childIndex,
            childAddress,
            childId,
            amount,
            true,
            to == address(0)
        );
    }

    function _transferActiveChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        uint256 amount,
        bytes memory data
    ) internal {
        Child storage child = _activeChildren[tokenId][childIndex];

        if (to == address(0)) {
            _removeChildByIndex(_activeChildren[tokenId], childIndex);
            delete _childIsInActive[childAddress][childId];
            INestableERC1155(childAddress).burn(childId, amount, 0);
        } else if (destinationId == 0) {
            _removeChildByIndex(_activeChildren[tokenId], childIndex);
            delete _childIsInActive[childAddress][childId];
            IERC1155(childAddress).safeTransferFrom(
                address(this),
                to,
                childId,
                amount,
                data
            );
        } else {
            _removeChildByIndex(_activeChildren[tokenId], childIndex);
            delete _childIsInActive[childAddress][childId];
            INestableERC1155(childAddress).nestTransferFrom(
                address(this),
                to,
                childId,
                amount,
                destinationId,
                data
            );
        }

        emit ChildTransferred(
            tokenId,
            childIndex,
            childAddress,
            childId,
            amount,
            false,
            to == address(0)
        );
    }

    function burn(
        uint256 tokenId,
        uint256 amount,
        uint256 maxRecursiveBurns
    ) public override nonReentrant returns (uint256) {
        (address immediateOwner, uint256 parentId, ) = directOwnerOf(tokenId);
        _burn(_msgSender(), tokenId, amount);

        uint256 burnedChildren = _recursiveBurn(tokenId, maxRecursiveBurns);

        delete _RMRKOwners[tokenId];

        emit NestTransfer(
            immediateOwner,
            address(0),
            parentId,
            0,
            tokenId,
            amount
        );

        return burnedChildren;
    }

    function _recursiveBurn(
        uint256 tokenId,
        uint256 maxRecursiveBurns
    ) internal returns (uint256) {
        uint256 burnedChildren = 0;
        Child[] memory children = _activeChildren[tokenId];

        for (
            uint256 i = 0;
            i < children.length && burnedChildren < maxRecursiveBurns;
            i++
        ) {
            Child memory child = children[i];
            if (child.contractAddress == address(this)) {
                burnedChildren +=
                    _recursiveBurn(
                        child.tokenId,
                        maxRecursiveBurns - burnedChildren
                    ) +
                    1;
            }
            delete _childIsInActive[child.contractAddress][child.tokenId];
        }

        delete _activeChildren[tokenId];
        delete _pendingChildren[tokenId];

        return burnedChildren;
    }

    function _addChild(
        uint256 parentId,
        Child memory child,
        bytes memory data
    ) internal {
        uint256 length = _pendingChildren[parentId].length;
        if (length >= 128) revert RMRKMaxPendingChildrenReached();

        _pendingChildren[parentId].push(child);

        emit ChildProposed(
            parentId,
            length,
            child.contractAddress,
            child.tokenId,
            child.amount
        );
    }

    function _acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) internal {
        Child memory child = _pendingChildren[parentId][childIndex];
        _removeChildByIndex(_pendingChildren[parentId], childIndex);

        _activeChildren[parentId].push(child);
        _childIsInActive[childAddress][childId] = 1;

        emit ChildAccepted(
            parentId,
            _activeChildren[parentId].length - 1,
            childAddress,
            childId,
            child.amount
        );
    }

    function _removeChildByIndex(
        Child[] storage array,
        uint256 index
    ) internal {
        require(index < array.length, "Index out of bounds");
        array[index] = array[array.length - 1];
        array.pop();
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender));
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _RMRKOwners[tokenId].ownerAddress != address(0);
    }

    error RMRKInsufficientParentBalance();
    error RMRKInsufficientChildBalance();

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(TipERC1155, IERC165) returns (bool) {
        return
            interfaceId == type(INestableERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override {
        super._mint(to, id, amount, data);
        _RMRKOwners[id] = DirectOwner({ownerAddress: to, tokenId: 0});
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual override {
        super._burn(from, id, amount);
        if (balanceOf(from, id) == 0) {
            delete _RMRKOwners[id];
        }
    }
}
