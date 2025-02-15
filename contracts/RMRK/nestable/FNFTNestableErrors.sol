// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.25;

/// Custom errors for FNFTNestable contract

error FNFTNestableParentTokenDoesNotExist();
error FNFTNestableCannotNestSelf();

error FNFTNestableCallerNotOwnerNorApproved();
error FNFTNestableChildDoesNotMatch();
error FNFTNestableChildIndexOutOfRange();
error FNFTNestableChildAddressMismatch();
error FNFTNestableChildIdMismatch();
error FNFTNestableCannotBurnNestedTokensDirectly();
error FNFTNestableNewOwnerIsCurrentOwner();

error FNFTNestableInsufficientParentBalance();
error FNFTNestableInsufficientChildBalance();

error FNFTNestableIndexOutOfBounds();
