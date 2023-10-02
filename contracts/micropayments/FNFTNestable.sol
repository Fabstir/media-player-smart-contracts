// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../RMRK/nestable/RMRKNestable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract FNFTNestable is RMRKNestable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function mint(address recipient) external returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _mint(recipient, newTokenId, "");
        return newTokenId;
    }
}
