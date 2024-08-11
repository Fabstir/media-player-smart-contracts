// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ERC4973/ABTToken.sol";

/**
 * @title FNFTFactoryABTToken
 * @dev This contract is responsible for deploying a new account-based token (ABT) contract.
 */
contract FNFTFactoryABTToken {
    event ABTTokenCreated(address abtToken);

    /**
     * @notice Deploys a new Subscription Token
     */

    function deploy(
        string memory name,
        string memory symbol,
        address eoa
    ) external {
        ABTToken abtToken = new ABTToken(name, symbol, msg.sender, eoa);

        emit ABTTokenCreated(address(abtToken));
    }
}
