// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.25;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {ERC165} from "./ERC165.sol";

import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {IERC4973} from "./interfaces/IERC4973.sol";
import "hardhat/console.sol";

bytes32 constant AGREEMENT_HASH = keccak256(
    "Agreement(address active,address passive,string tokenURI)"
);

/// @notice Reference implementation of EIP-4973 tokens.
/// @author Tim Daubenschütz, Rahul Rumalla (https://github.com/rugpullindex/ERC4973/blob/master/src/ERC4973.sol)
abstract contract ERC4973 is EIP712, ERC165, IERC721Metadata, IERC4973 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    using BitMaps for BitMaps.BitMap;
    BitMaps.BitMap private _usedHashes;

    string private _name;
    string private _symbol;

    address private _minter;
    address private _eoa;
    mapping(uint256 => address) private _minters;
    mapping(address => address) private _eoas;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256) private _balances;
    mapping(uint256 => uint256) private _inventory;
    bool _isMinter;
    bool _isEOA;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory version,
        address minter_,
        address eoa
    ) EIP712(name_, version) {
        _name = name_;
        _symbol = symbol_;

        _isMinter = minter_ != address(0);
        _minter = minter_;

        _eoa = eoa;
        _isEOA = _eoa != address(0);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC4973).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(_exists(tokenId), "tokenURI: token doesn't exist");
        return _tokenURIs[tokenId];
    }

    function nextTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function unequip(uint256 tokenId) public virtual override {
        require(
            msg.sender == ownerOf(tokenId) ||
                msg.sender == _minter ||
                msg.sender == _minters[_inventory[tokenId]],
            "unequip: sender must be owner or deployment account"
        );
        _burn(tokenId);
    }

    function balanceOf(
        address owner
    ) public view virtual override returns (uint256) {
        require(
            owner != address(0),
            "balanceOf: address zero is not a valid owner"
        );
        return _balances[owner];
    }

    function minter() public view virtual returns (address) {
        require(
            !_isMinter || _minter != address(0),
            "minter: token doesn't exist"
        );
        return _minter;
    }

    function minterOf(uint256 tokenId) public view virtual returns (address) {
        require(
            _isMinter || _minters[_inventory[tokenId]] != address(0),
            "minter: token doesn't exist"
        );
        return _minter;
    }

    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ownerOf: token doesn't exist");
        return owner;
    }

    function setEOA(address account, address eoa) external {
        require(msg.sender == _minter, "setEOA: Not authorised");
        _eoas[account] = eoa;
    }

    function give(
        //  address from, // is the `msg.sender`,
        address to,
        string calldata uri,
        bytes calldata signature
    ) external virtual override returns (uint256) {
        require(
            !_isMinter || msg.sender == _minter,
            "give: only deployment account can give"
        );
        require(msg.sender != to, "give: cannot give from self");
        uint256 index = _safeCheckAgreement(msg.sender, to, uri, signature);
        uint256 tokenId = _tokenIds.current();
        _inventory[tokenId] = index;

        require(!_usedHashes.get(index), "mint: token already minted");
        _mint(to, tokenId, uri);

        if (!_isMinter) _minters[index] = msg.sender;

        _tokenIds.increment();

        _usedHashes.set(index);
        return tokenId;
    }

    function take(
        address from,
        //  address to, // is the `msg.sender`,
        string calldata uri,
        bytes calldata signature
    ) external virtual override returns (uint256) {
        require(
            !_isMinter || from == _minter,
            "take: must be from deployment account"
        );
        require(msg.sender != from, "take: cannot take from self");
        uint256 index = _safeCheckAgreement(msg.sender, from, uri, signature);
        uint256 tokenId = _tokenIds.current();
        _inventory[tokenId] = index;

        require(!_usedHashes.get(index), "mint: token already minted");
        _mint(msg.sender, tokenId, uri);

        if (!_isMinter) _minters[index] = from;

        _tokenIds.increment();

        _usedHashes.set(index);
        return tokenId;
    }

    function revoke(
        address from,
        string calldata uri,
        bytes calldata signature
    ) external virtual returns (uint256) {
        require(
            !_isMinter || msg.sender == _minter,
            "revoke: can only be done by deployment account"
        );
        uint256 index = _safeCheckAgreement(from, msg.sender, uri, signature);
        uint256 tokenId = _tokenIds.current();
        _inventory[tokenId] = index;

        require(
            _isMinter || msg.sender == _minters[_inventory[tokenId]],
            "revoke: can only be done by minter account"
        );

        require(
            !_usedHashes.get(index),
            "mint: token already minted or revoked"
        );
        _mint(address(0x0), tokenId, uri);

        _tokenIds.increment();

        _usedHashes.set(index);
        return tokenId;
    }

    function isUsed(
        address active,
        address passive,
        string calldata uri
    ) external view virtual returns (bool) {
        bytes32 hash = _getHash(active, passive, uri);
        uint256 index = uint256(hash);

        return _usedHashes.get(index);
    }

    function _safeCheckAgreement(
        address active,
        address passive,
        string calldata uri,
        bytes calldata signature
    ) internal view virtual returns (uint256) {
        console.log("_safeCheckAgreement: active = ", active);
        console.log("_safeCheckAgreement: passive = ", passive);
        console.log("_safeCheckAgreement: uri = ", uri);

        bytes32 hash = _getHash(active, passive, uri);

        uint256 index = uint256(hash);
        console.log("_safeCheckAgreement: hash index = ", index);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, hash));

        address recoveredAddress = recoverSigner(
            prefixedHashMessage,
            signature
        );
        console.log(
            "_safeCheckAgreement: recoveredAddress = ",
            recoveredAddress
        );

        address resolvedEOA = _eoas[passive] != address(0x0)
            ? _eoas[passive]
            : _eoa;

        require(
            recoverSigner(prefixedHashMessage, signature) == resolvedEOA,
            //            SignatureChecker.isValidSignatureNow(passive, hash, signature),
            "_safeCheckAgreement: invalid signature"
        );

        require(!_usedHashes.get(index), "_safeCheckAgreement: already used");
        return index;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function _getHash(
        address active,
        address passive,
        string calldata tokenURI_
    ) internal view returns (bytes32) {
        console.log("_getHash: active = ", active);
        console.log("_getHash: passive = ", passive);
        console.log("_getHash: tokenURI_ = ", tokenURI_);

        bytes32 structHash = keccak256(
            abi.encode(
                AGREEMENT_HASH,
                active,
                passive,
                keccak256(bytes(tokenURI_))
            )
        );
        console.log("_getHash: structHash = ", uint256(structHash));

        return _hashTypedDataV4(structHash);
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _mint(
        address to,
        uint256 tokenId,
        string memory uri
    ) internal virtual returns (uint256) {
        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = uri;
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];
        delete _tokenURIs[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }
}
