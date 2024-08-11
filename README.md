# Fabstir Media Player - smart contracts

This project includes implementations of ERC721, ERC1155 and RMRK's ERC7401 NFT contracts
plus a new nestable NFT structure for semi-fungible ERC1155 contract.
Smart contracts are written in Solidity.

The ERC721 and ERC1155 also include implementation for EIP-4393: Micropayments for NFTs and Multi Tokens  
This allows tipping to holders of NFTs and multi tokens.

## Installation

yarn install

## Deploy smart contacts

npx hardhat node --config hardhat.config.js --port 8546
npx hardhat run --config hardhat.config.js --network localhost1 scripts/deployAll.js

## Copyright and Attribution Notice

RMRK Integration
Parts of this project integrate code from RMRK, which is licensed under the Apache License, Version 2.0. We have included specific files from their open-source repository in our project.
