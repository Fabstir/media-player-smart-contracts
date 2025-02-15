// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "../../micropayments/TipERC1155.sol";
import "./INestableERC1155.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../library/RMRKErrors.sol";
import "./FNFTNestableErrors.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";

contract FNFTNestableERC1155 is
    Initializable,
    TipERC1155,
    INestableERC1155,
    ERC1155ReceiverUpgradeable
{
    using Address for address;

    // Mapping from token ID to direct owner
    mapping(address => mapping(uint256 => DirectOwner)) _RMRKOwners;

    // Mapping from token ID to array of active children structs
    mapping(uint256 => Child[]) internal _activeChildren;

    // Mapping from token ID to array of pending children structs
    mapping(uint256 => Child[]) internal _pendingChildren;

    function initialize() public override initializer {
        __TipERC1155_init();
    }

    struct TransferChildParams {
        uint256 tokenId;
        address to;
        uint256 destinationId;
        uint256 childIndex;
        address childAddress;
        uint256 childId;
        uint256 amount;
        bytes data;
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

        // For a root token (not nested), set the direct owner to the minter (account)
        _RMRKOwners[address(this)][newTokenId] = DirectOwner({
            tokenId: 0, // Indicates root token (non-nested)
            ownerAddress: account
        });

        return newTokenId;
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        (address currentOwner, uint256 parentId, bool isNft) = directOwnerOf(
            tokenId
        );
        // Traverse up the ownership chain until we reach an EOA or non-NFT contract
        while (isNft) {
            (currentOwner, parentId, isNft) = INestableERC1155(currentOwner)
                .directOwnerOf(parentId);
        }
        return currentOwner;
    }

    function directOwnerOf(
        uint256 tokenId
    ) public view override returns (address, uint256, bool) {
        DirectOwner memory owner = _RMRKOwners[address(this)][tokenId];
        if (owner.ownerAddress == address(0)) revert RMRKPartDoesNotExist();

        // Token is nested if it has a parent token ID
        bool isNft = owner.tokenId > 0;
        return (owner.ownerAddress, owner.tokenId, isNft);
    }

    function addChild(
        uint256 parentId,
        uint256 childId,
        bytes memory data
    ) public override {
        if (!_exists(parentId)) revert FNFTNestableParentTokenDoesNotExist();
        address childAddress = _msgSender();
        if (childAddress == address(this)) revert FNFTNestableCannotNestSelf();

        if (!_isApprovedOrOwner(_msgSender(), parentId))
            revert FNFTNestableCallerNotOwnerNorApproved();

        uint256 parentBalance = balanceOf(
            _RMRKOwners[address(this)][parentId].ownerAddress,
            parentId
        );
        if (parentBalance == 0) revert FNFTNestableInsufficientChildBalance();

        uint256 childBalance = IERC1155(childAddress).balanceOf(
            _msgSender(),
            childId
        );
        if (childBalance < parentBalance)
            revert FNFTNestableInsufficientChildBalance();

        Child memory child = Child({
            tokenId: childId,
            contractAddress: childAddress,
            amount: parentBalance
        });

        _addChild(parentId, child, data);
    }

    // Implementation uses direct nesting model rather than proposal/acceptance model
    // Can only add a balance of child tokens equal to the parent balance
    function addChildNFT(
        uint256 parentId,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) public virtual {
        if (!_exists(parentId)) revert RMRKTokenDoesNotHaveAsset();

        if (!_isApprovedOrOwner(_msgSender(), parentId))
            revert FNFTNestableCallerNotOwnerNorApproved();

        // Check if parent has a parent (is nested)
        (
            address parentOwner,
            uint256 grandParentId,
            bool isNft
        ) = directOwnerOf(parentId);

        uint256 parentBalance;
        if (isNft) {
            // Check balance in parent's contract context
            parentBalance = IERC1155(address(this)).balanceOf(
                parentOwner,
                parentId
            );
        } else {
            parentBalance = balanceOf(parentOwner, parentId);
        }

        if (parentBalance == 0) revert FNFTNestableInsufficientChildBalance();

        uint256 childBalance = IERC1155(childAddress).balanceOf(
            _msgSender(),
            childId
        );
        if (childBalance < parentBalance)
            revert FNFTNestableInsufficientChildBalance();

        if (
            IERC165Upgradeable(childAddress).supportsInterface(
                type(INestableERC1155).interfaceId
            )
        ) {
            // Use nestTransferFrom
            INestableERC1155(childAddress).nestTransferFrom(
                _msgSender(),
                address(this),
                childId,
                parentBalance,
                parentId,
                data
            );
        } else {
            // Regular ERC1155 transfer
            IERC1155(childAddress).safeTransferFrom(
                _msgSender(),
                address(this),
                childId,
                parentBalance,
                data
            );
        }

        // Add this child to the active children array.
        Child memory newChild = Child({
            tokenId: childId,
            contractAddress: childAddress,
            amount: parentBalance
        });
        _activeChildren[parentId].push(newChild);

        emit NestTransfer(
            _msgSender(), // from: previous owner
            address(this), // to: this contract
            0, // fromTokenId: 0 as not nested before
            parentId, // toTokenId: parent's token ID
            childId, // tokenId: child token being transferred
            parentBalance // amount being transferred
        );
    }

    function acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) public override {
        if (!_isApprovedOrOwner(_msgSender(), parentId))
            revert FNFTNestableCallerNotOwnerNorApproved();
        Child memory child = pendingChildOf(parentId, childIndex);
        if (child.contractAddress != childAddress || child.tokenId != childId)
            revert FNFTNestableChildDoesNotMatch();

        _acceptChild(parentId, childIndex, childAddress, childId);
    }

    function rejectAllChildren(
        uint256 parentId,
        uint256 maxRejections
    ) public override {
        if (!_isApprovedOrOwner(_msgSender(), parentId))
            revert FNFTNestableCallerNotOwnerNorApproved();

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
        // If approval check fails, log before revert:
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert FNFTNestableCallerNotOwnerNorApproved();
        }

        Child[] storage childrenArray = isPending
            ? _pendingChildren[tokenId]
            : _activeChildren[tokenId];

        if (childIndex >= childrenArray.length) {
            revert FNFTNestableChildIndexOutOfRange();
        }
        if (childrenArray[childIndex].contractAddress != childAddress) {
            revert FNFTNestableChildAddressMismatch();
        }
        if (childrenArray[childIndex].tokenId != childId) {
            revert FNFTNestableChildIdMismatch();
        }

        // Use amount stored when child was nested
        uint256 amount = childrenArray[childIndex].amount;

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
                TransferChildParams({
                    tokenId: tokenId,
                    to: to,
                    destinationId: destinationId,
                    childIndex: childIndex,
                    childAddress: childAddress,
                    childId: childId,
                    amount: amount,
                    data: data
                })
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
            _RMRKOwners[address(this)][tokenId] = DirectOwner({
                ownerAddress: to,
                tokenId: destinationId
            });
        } else {
            delete _RMRKOwners[address(this)][tokenId];
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
        if (!_isApprovedOrDirectOwner(sender, tokenId))
            revert FNFTNestableCallerNotOwnerNorApproved();

        // Check that the new owner is not the zero address
        if (newOwner == address(0)) revert RMRKNewOwnerIsZeroAddress();

        // Check that the new owner is not the current owner
        if (currentOwner == newOwner)
            revert FNFTNestableNewOwnerIsCurrentOwner();

        // Update the owner in the RMRK ownership structure
        _RMRKOwners[address(this)][tokenId] = DirectOwner({
            ownerAddress: newOwner,
            tokenId: 0 // Reset to 0 as it's now owned by an address, not a token
        });

        // Emit the OwnershipTransferred event
        emit TokenOwnershipTransferred(tokenId, currentOwner, newOwner);
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

    function _transferActiveChild(TransferChildParams memory params) internal {
        // Remove child from active children array
        _removeChildByIndex(_activeChildren[params.tokenId], params.childIndex);

        if (params.to == address(0)) {
            // Burn child
            INestableERC1155(params.childAddress).burn(
                params.childId,
                params.amount,
                0
            );
        } else if (params.destinationId == 0) {
            // Transfer to EOA - first update child's ownership record
            _RMRKOwners[params.childAddress][params.childId] = DirectOwner({
                tokenId: 0, // Not nested anymore
                ownerAddress: params.to // New EOA owner
            });

            // Transfer child token to EOA
            IERC1155(params.childAddress).safeTransferFrom(
                address(this),
                params.to,
                params.childId,
                params.amount,
                params.data
            );
        } else {
            // Transfer to another NFT
            INestableERC1155(params.childAddress).nestTransferFrom(
                address(this),
                params.to,
                params.childId,
                params.amount,
                params.destinationId,
                params.data
            );
        }

        emit ChildTransferred(
            params.tokenId,
            params.childIndex,
            params.childAddress,
            params.childId,
            params.amount,
            false,
            params.to == address(0)
        );
    }
    function burn(
        uint256 tokenId,
        uint256 amount,
        uint256 maxRecursiveBurns
    ) public override nonReentrant returns (uint256) {
        (address immediateOwner, uint256 parentId, ) = directOwnerOf(tokenId);

        super._burn(_msgSender(), tokenId, amount);
        if (balanceOf(_msgSender(), tokenId) == 0) {
            delete _RMRKOwners[address(this)][tokenId];
        }

        uint256 burnedChildren = _recursiveBurn(tokenId, maxRecursiveBurns);

        delete _RMRKOwners[address(this)][tokenId];

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
        if (index >= array.length) revert FNFTNestableIndexOutOfBounds();

        uint256 lastIndex = array.length - 1;

        if (index != lastIndex) {
            // Move last element to the index being removed
            array[index] = array[lastIndex];
        }

        // Remove last element
        array.pop();
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        bool isApproved = isApprovedForAll(owner, spender);
        bool result = (spender == owner || isApproved);
        return result;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _RMRKOwners[address(this)][tokenId].ownerAddress != address(0);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(TipERC1155, ERC1155ReceiverUpgradeable, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(INestableERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        // You can customize logic if needed.
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        // You can customize logic if needed.
        return this.onERC1155BatchReceived.selector;
    }
}
