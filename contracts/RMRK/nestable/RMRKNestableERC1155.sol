// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.25;

import "./INestableERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../library/RMRKErrors.sol";

/**
 * @title RMRKNestableERC1155
 * @dev Implementation of the ERC-1155 standard with additional nestable functionality.
 * This contract extends the basic ERC-1155 functionality by allowing tokens to be nested within other tokens.
 * It also implements the IERC1155Receiver interface to handle safe transfers.
 *
 * @notice This contract is based off the RMRK protocol, which aims to extend the functionality of NFTs.
 */
contract RMRKNestableERC1155 is Context, ERC165, IERC1155, INestableERC1155, IERC1155Receiver {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping from token ID to DirectOwner struct
    mapping(uint256 => DirectOwner) private _RMRKOwners;

    // Mapping of tokenId to array of active children structs
    mapping(uint256 => Child[]) internal _activeChildren;

    // Mapping of tokenId to array of pending children structs
    mapping(uint256 => Child[]) internal _pendingChildren;

    // Mapping of child token address to child token ID to whether they are pending or active on any token
    mapping(address => mapping(uint256 => uint256)) internal _childIsInActive;

struct ChildTransferParams {
    uint256 tokenId;
    address to;
    uint256 destinationId;
    uint256 childIndex;
    address childAddress;
    uint256 childId;
    uint256 amount;
    bool isPending;
    bytes data;
}

error RMRKInsufficientParentBalance();
error RMRKInsufficientChildBalance();

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(INestableERC1155).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        (address owner, uint256 ownerTokenId, bool isNft) = directOwnerOf(tokenId);
        if (isNft) {
            owner = INestableERC1155(owner).ownerOf(ownerTokenId);
        }
        return owner;
    }

function transferOwnership(uint256 tokenId, address newOwner) public virtual {
    address sender = _msgSender();
    (address currentOwner, , bool isNft) = directOwnerOf(tokenId);
    
    // Check if the sender is the owner or approved
    require(_isApprovedOrDirectOwner(sender, tokenId), "RMRKNestableERC1155: transfer caller is not owner nor approved");
    
    // Check that the new owner is not the zero address
    require(newOwner != address(0), "RMRKNestableERC1155: new owner is the zero address");
    
    // Check that the new owner is not the current owner
    require(currentOwner != newOwner, "RMRKNestableERC1155: new owner is the current owner");

    // Update the owner in the RMRK ownership structure
    _RMRKOwners[tokenId] = DirectOwner({
        ownerAddress: newOwner,
        tokenId: 0  // Reset to 0 as it's now owned by an address, not a token
    });

    // Emit the OwnershipTransferred event
    emit OwnershipTransferred(tokenId, currentOwner, newOwner);
}

    function directOwnerOf(uint256 tokenId) public view virtual override returns (address, uint256, bool) {
        DirectOwner memory owner = _RMRKOwners[tokenId];
        if (owner.ownerAddress == address(0)) revert RMRKTokenDoesNotHaveAsset();
        return (owner.ownerAddress, owner.tokenId, owner.tokenId != 0);
    }

    function burn(uint256 tokenId, uint256 amount, uint256 maxRecursiveBurns) public virtual override returns (uint256) {
        (address immediateOwner, uint256 parentId, ) = directOwnerOf(tokenId);
        _burn(_msgSender(), tokenId, amount);

        uint256 burnedChildren = _recursiveBurn(tokenId, maxRecursiveBurns);

        delete _RMRKOwners[tokenId];

        emit NestTransfer(immediateOwner, address(0), parentId, 0, tokenId, amount);

        return burnedChildren;
    }

function addChild(
    uint256 parentId,
    uint256 childId,
    bytes memory data
) public virtual override {
    _requireMinted(parentId);
    address childAddress = _msgSender();
    if (!childAddress.isContract()) revert RMRKIsNotContract();

    uint256 parentBalance = balanceOf(_msgSender(), parentId);
    if (parentBalance == 0) revert RMRKInsufficientParentBalance();

    // Ensure the child balance matches the parent balance
    if (IERC1155(childAddress).balanceOf(_msgSender(), childId) < parentBalance) revert RMRKInsufficientChildBalance();

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
    _requireMinted(parentId);
    uint256 parentBalance = balanceOf(_msgSender(), parentId);
    if (parentBalance == 0) revert RMRKInsufficientParentBalance();

    if (IERC1155(childAddress).balanceOf(_msgSender(), childId) < parentBalance) revert RMRKInsufficientChildBalance();

    IERC1155(childAddress).safeTransferFrom(_msgSender(), address(this), childId, parentBalance, data);

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
) public virtual override {
    _requireMinted(parentId);
    if (!_isApprovedOrOwner(_msgSender(), parentId)) revert RMRKNotApprovedOrDirectOwner();

    uint256 parentBalance = balanceOf(_msgSender(), parentId);
    if (parentBalance == 0) revert RMRKInsufficientParentBalance();

    Child memory child = pendingChildOf(parentId, childIndex);
    if (child.contractAddress != childAddress || child.tokenId != childId || child.amount != parentBalance) revert RMRKUnexpectedChildId();
    if (_childIsInActive[childAddress][childId] != 0) revert RMRKChildAlreadyExists();

    _acceptChild(parentId, childIndex, childAddress, childId);
}

    function rejectAllChildren(uint256 tokenId, uint256 maxRejections) public virtual override {
        _requireMinted(tokenId);
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert RMRKNotApprovedOrDirectOwner();

        if (_pendingChildren[tokenId].length > maxRejections) revert RMRKUnexpectedNumberOfChildren();

        delete _pendingChildren[tokenId];
        emit AllChildrenRejected(tokenId);
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
) public virtual override {
    _requireMinted(tokenId);
    if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert RMRKNotApprovedOrDirectOwner();

    uint256 parentBalance = balanceOf(_msgSender(), tokenId);
    if (parentBalance == 0) revert RMRKInsufficientParentBalance();

    ChildTransferParams memory params = ChildTransferParams({
        tokenId: tokenId,
        to: to,
        destinationId: destinationId,
        childIndex: childIndex,
        childAddress: childAddress,
        childId: childId,
        amount: parentBalance,
        isPending: isPending,
        data: data
    }); 

    _transferChild(params);
}

    function childrenOf(uint256 parentId) public view virtual override returns (Child[] memory) {
        return _activeChildren[parentId];
    }

    function pendingChildrenOf(uint256 parentId) public view virtual override returns (Child[] memory) {
        return _pendingChildren[parentId];
    }

    function childOf(uint256 parentId, uint256 index) public view virtual override returns (Child memory) {
        if (index >= _activeChildren[parentId].length) revert RMRKChildIndexOutOfRange();
        return _activeChildren[parentId][index];
    }

    function pendingChildOf(uint256 parentId, uint256 index) public view virtual override returns (Child memory) {
        if (index >= _pendingChildren[parentId].length) revert RMRKPendingChildIndexOutOfRange();
        return _pendingChildren[parentId][index];
    }

    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 destinationId,
        bytes memory data
    ) public virtual override {
        _requireMinted(tokenId);
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert RMRKNotApprovedOrDirectOwner();

        _nestTransfer(from, to, tokenId, amount, destinationId, data);
    }

    function _addChild(uint256 parentId, Child memory child, bytes memory data) internal virtual {
        uint256 length = _pendingChildren[parentId].length;
        if (length >= 128) revert RMRKMaxPendingChildrenReached();

        _pendingChildren[parentId].push(child);

        emit ChildProposed(parentId, length, child.contractAddress, child.tokenId, child.amount);
    }

    function _acceptChild(uint256 parentId, uint256 childIndex, address childAddress, uint256 childId) internal virtual {
        Child memory child = _pendingChildren[parentId][childIndex];
        _removeChildByIndex(_pendingChildren[parentId], childIndex);

        _activeChildren[parentId].push(child);
        _childIsInActive[childAddress][childId] = 1;

        emit ChildAccepted(parentId, _activeChildren[parentId].length - 1, childAddress, childId, child.amount);
    }

function _transferChild(ChildTransferParams memory params) internal virtual {
    Child memory child;
    if (params.isPending) {
        child = pendingChildOf(params.tokenId, params.childIndex);
        _removeChildByIndex(_pendingChildren[params.tokenId], params.childIndex);
    } else {
        child = childOf(params.tokenId, params.childIndex);
        delete _childIsInActive[params.childAddress][params.childId];
        _removeChildByIndex(_activeChildren[params.tokenId], params.childIndex);
    }

    if (params.to != address(0)) {
        if (params.destinationId == 0) {
            IERC1155(params.childAddress).safeTransferFrom(address(this), params.to, params.childId, params.amount, params.data);
        } else {
            INestableERC1155(params.childAddress).nestTransferFrom(address(this), params.to, params.childId, params.amount, params.destinationId, params.data);
        }
    }

    emit ChildTransferred(params.tokenId, params.childIndex, params.childAddress, params.childId, params.amount, params.isPending, params.to == address(0));
}

function _nestTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 amount,
    uint256 destinationId,
    bytes memory data
) internal virtual {
    (address immediateOwner, uint256 parentId, ) = directOwnerOf(tokenId);
    if (immediateOwner != from) revert RMRKUnexpectedParent();
    if (to == address(0)) revert RMRKNewOwnerIsZeroAddress();
    if (to == address(this) && tokenId == destinationId) revert RMRKNestableTransferToSelf();

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(tokenId);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, from, to, ids, amounts, data);

    _balances[tokenId][from] -= amount;
    _balances[tokenId][to] += amount;

    _RMRKOwners[tokenId] = DirectOwner({ownerAddress: to, tokenId: destinationId});

    emit TransferSingle(operator, from, to, tokenId, amount);
    emit NestTransfer(from, to, parentId, destinationId, tokenId, amount);

    _afterTokenTransfer(operator, from, to, ids, amounts, data);

    _doSafeTransferAcceptanceCheck(operator, from, to, tokenId, amount, data);
}

    function _recursiveBurn(uint256 tokenId, uint256 maxRecursiveBurns) internal virtual returns (uint256) {
        uint256 burnedChildren = 0;
        Child[] memory children = _activeChildren[tokenId];

        for (uint256 i = 0; i < children.length && burnedChildren < maxRecursiveBurns; i++) {
            Child memory child = children[i];
            if (child.contractAddress == address(this)) {
                burnedChildren += _recursiveBurn(child.tokenId, maxRecursiveBurns - burnedChildren) + 1;
            }
            delete _childIsInActive[child.contractAddress][child.tokenId];
        }

        delete _activeChildren[tokenId];
        delete _pendingChildren[tokenId];

        return burnedChildren;
    }

    function _removeChildByIndex(Child[] storage array, uint256 index) private {
        if (index >= array.length) revert RMRKIndexOutOfRange();
        array[index] = array[array.length - 1];
        array.pop();
    }

    function _requireMinted(uint256 tokenId) internal view virtual {
        if (!_exists(tokenId)) revert RMRKTokenDoesNotHaveAsset();
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _RMRKOwners[tokenId].ownerAddress != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender));
    }

    function _isApprovedOrDirectOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        (address owner, uint256 parentId, ) = directOwnerOf(tokenId);
        // When the parent is an NFT, only it can do operations
        if (parentId != 0) {
            return (spender == owner);
        }
        // Otherwise, the owner or approved address can
        return (spender == owner ||
            isApprovedForAll(owner, spender));
    }


    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // Implement other INestableERC1155 functions here...

function _safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
) internal virtual {
    require(to != address(0), "ERC1155: transfer to the zero address");

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, from, to, ids, amounts, data);

    uint256 fromBalance = _balances[id][from];
    require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
    unchecked {
        _balances[id][from] = fromBalance - amount;
    }
    _balances[id][to] += amount;

    emit TransferSingle(operator, from, to, id, amount);

    _afterTokenTransfer(operator, from, to, ids, amounts, data);

    _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);

    // Transfer the corresponding amount of child NFTs
    _transferChildrenEqually(from, to, id, amount);
}

function _transferChildrenEqually(
    address from,
    address to,
    uint256 parentId,
    uint256 amount
) internal {
    Child[] storage children = _activeChildren[parentId];
    uint256 parentBalanceFrom = _balances[parentId][from];
    uint256 parentBalanceTo = _balances[parentId][to];

    for (uint i = 0; i < children.length; i++) {
        Child storage child = children[i];
        
        uint256 childAmount = (child.amount * amount) / (parentBalanceFrom + amount);
        
        if (childAmount > 0) {
            // Decrease the child amount for the sender
            child.amount -= childAmount;

            // Add or update the child for the recipient
            _addOrUpdateChild(to, parentId, Child({
                tokenId: child.tokenId,
                contractAddress: child.contractAddress,
                amount: childAmount
            }));

            // Emit the transfer event
            emit ChildTransferred(parentId, i, child.contractAddress, child.tokenId, childAmount, false, false);
        }
    }

    // Remove any children that have been completely transferred
    for (uint i = children.length; i > 0; i--) {
        if (children[i-1].amount == 0) {
            _removeChildByIndex(_activeChildren[parentId], i-1);
        }
    }
}

function _addOrUpdateChild(address owner, uint256 parentId, Child memory child) internal {
    Child[] storage children = _activeChildren[parentId];
    for (uint i = 0; i < children.length; i++) {
        if (children[i].contractAddress == child.contractAddress && children[i].tokenId == child.tokenId) {
            children[i].amount += child.amount;
            return;
        }
    }
    children.push(child);
}
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    // Implement IERC1155Receiver functions
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

function _mint(
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
) internal virtual {
    require(to != address(0), "RMRKNestableERC1155: mint to the zero address");

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

    _balances[id][to] += amount;
    _RMRKOwners[id] = DirectOwner({ownerAddress: to, tokenId: 0});

    emit TransferSingle(operator, address(0), to, id, amount);

    _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

    _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
}

function _mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
) internal virtual {
    require(to != address(0), "RMRKNestableERC1155: mint to the zero address");
    require(ids.length == amounts.length, "RMRKNestableERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

    for (uint256 i = 0; i < ids.length; i++) {
        _balances[ids[i]][to] += amounts[i];
        _RMRKOwners[ids[i]] = DirectOwner({ownerAddress: to, tokenId: 0});
    }

    emit TransferBatch(operator, address(0), to, ids, amounts);

    _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

    _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
}

function _burn(
    address from,
    uint256 id,
    uint256 amount
) internal virtual {
    require(from != address(0), "RMRKNestableERC1155: burn from the zero address");

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

    uint256 fromBalance = _balances[id][from];
    require(fromBalance >= amount, "RMRKNestableERC1155: burn amount exceeds balance");
    unchecked {
        _balances[id][from] = fromBalance - amount;
    }

    delete _RMRKOwners[id];

    emit TransferSingle(operator, from, address(0), id, amount);

    _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
}

function _burnBatch(
    address from,
    uint256[] memory ids,
    uint256[] memory amounts
) internal virtual {
    require(from != address(0), "RMRKNestableERC1155: burn from the zero address");
    require(ids.length == amounts.length, "RMRKNestableERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

    for (uint256 i = 0; i < ids.length; i++) {
        uint256 id = ids[i];
        uint256 amount = amounts[i];

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "RMRKNestableERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        delete _RMRKOwners[id];
    }

    emit TransferBatch(operator, from, address(0), ids, amounts);

    _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
}    
}