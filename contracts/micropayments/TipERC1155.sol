// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../prototype3_EIP3601/IFNFTPayback.sol";
import "./ITipToken.sol";
import "hardhat/console.sol";
import "./Playlist.sol";

/**
 * @title TipERC1155
 * @dev TipERC1155 is a smart contract that extends the ERC1155 standard to include tipping functionality.
 * This contract allows users to send tips to the owners of ERC1155 tokens.
 *
 * @notice This contract is part of a system that enables users to tip the owners of ERC1155 tokens,
 * adding an additional layer of interaction and monetisation.
 */
contract TipERC1155 is
    Initializable,
    IFNFTPayback,
    ERC1155Upgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    NFTPlaylist
{
    // Mapping from NFT token to payback fractional nft tokens
    address[] _fnftTokens;
    // Mapping from FNFTToken to payback ratios
    mapping(address => uint256) _paybacks;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => address) private _tokenMinters;

    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    function initialize() public initializer {
        __ERC1155_init("");
        __ReentrancyGuard_init();
        __Ownable_init();
        __AccessControl_init();
        __Pausable_init();
        __ERC1155Burnable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(URI_SETTER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);

        // Increment the token ID counter to 1
        _tokenIds.increment();
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return (_tokenURIs[tokenId]);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public override {
        super.setApprovalForAll(operator, approved);
    }

    /**
        @notice ERC-1155 allows for shared holders of a token id. Here, each contributor is a holder and the fractional
         sharing percentage between them can be represented by the balance that each holds in the ERC-1155 token Id.
         Note if token Id is zero then this implementation will assign the next available token Id for the NFT to be 
         minted. Else token Id is used.
        @param account The user account
        @param tokenId The token Id
        @param tokenURI The token URI
        @param amount The amount of tokens to mint
        @param data Any extra data to be passed in
        @return The token id minted
    */
    function mintToken(
        address account,
        uint256 tokenId,
        string memory tokenURI,
        uint256 amount,
        bytes memory data
    ) public returns (uint256) {
        console.log("TipERC1155: mintToken inside");

        uint256 newTokenId;

        if (tokenId == 0) {
            newTokenId = _tokenIds.current();
            _tokenMinters[newTokenId] = msg.sender;
        } else newTokenId = tokenId;

        require(
            _tokenMinters[newTokenId] == msg.sender,
            "ERC1155: caller does not have minter role for this token ID"
        );

        console.log("TipERC1155: mintToken newTokenId = ", newTokenId);

        _mint(account, newTokenId, amount, data);
        console.log("TipERC1155: mintToken mint");

        _setTokenUri(newTokenId, tokenURI);
        console.log("TipERC1155: mintToken _setTokenUri");

        if (tokenId == 0) _tokenIds.increment();
        console.log(
            "TipERC1155: mintToken _tokenIds.current()",
            _tokenIds.current()
        );

        return newTokenId;
    }

    /**
     * @dev Mint multiple ERC1155 tokens with different token URIs and amounts.
     * @param to Address to mint tokens to.
     * @param tokenURIs Array of token URIs to mint.
     * @param amounts Array of amounts to mint for each token URI.
     * @param data Optional data to pass to the recipient if minting to a contract.
     * Requirements:
     * - `to` cannot be the zero address.
     * - `tokenURIs` and `amounts` arrays must have the same length, unless `tokenURIs` has length 1.
     * - If `tokenURIs` has length 1, mint multiple tokens with the same URI and different amounts.
     * - If `tokenURIs` has length greater than 1, mint multiple tokens with different URIs and amounts.
     */
    function mintTokenBatch(
        address[] memory to,
        string[] memory tokenURIs,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        require(
            tokenURIs.length == 1 || tokenURIs.length == amounts.length,
            "TipERC1155: tokenURIs and amounts length mismatch"
        );

        if (tokenURIs.length == 1) {
            _tokenMinters[_tokenIds.current()] = msg.sender;

            for (uint256 i = 0; i < amounts.length; i++) {
                require(
                    to[i] != address(0),
                    "ERC1155: mint to the zero address"
                );

                (bool success, bytes memory result) = address(this)
                    .delegatecall(
                        abi.encodeWithSignature(
                            "mintToken(address,uint256,string,uint256,bytes)",
                            to[i],
                            _tokenIds.current(),
                            tokenURIs[0],
                            amounts[i],
                            data
                        )
                    );
                require(
                    success,
                    "TipERC1155: delegatecall to mintToken failed"
                );
            }

            _tokenIds.increment();
        } else {
            for (uint256 i = 0; i < amounts.length; i++) {
                require(
                    to[i] != address(0),
                    "ERC1155: mint to the zero address"
                );

                (bool success, bytes memory result) = address(this)
                    .delegatecall(
                        abi.encodeWithSignature(
                            "mintToken(address,uint256,string,uint256,bytes)",
                            to[i],
                            0,
                            tokenURIs[i],
                            amounts[i],
                            data
                        )
                    );
                require(
                    success,
                    "TipERC1155: delegatecall to mintToken failed"
                );
            }
        }
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(IFNFTPayback).interfaceId;
    }

    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override {
        require(account != address(0), "ERC1155: mint to the zero address");
        require(
            super.isApprovedForAll(address(this), account) == false,
            "Account already has a subscription"
        );
        super._mint(account, id, amount, data);
    }

    function _setTokenUri(uint256 tokenId, string memory tokenURI) private {
        _tokenURIs[tokenId] = tokenURI;
    }

    function fnftTokens() external view override returns (address[] memory) {
        return _fnftTokens;
    }

    function payback(
        address fnftToken
    ) external view override returns (uint256) {
        return _paybacks[fnftToken];
    }

    function addFNFTTokenPayback(
        address fnftToken,
        uint256 payback_
    ) external override {
        require(payback_ > 0, "Payback must be greater than 0");
        console.log("addFNFTTokenPayback: fnftToken = ", fnftToken);

        console.log(
            "addFNFTTokenPayback: before _fnftTokens.length = ",
            _fnftTokens.length
        );
        console.log(
            "addFNFTTokenPayback: before _paybacks[fnftToken] = ",
            _paybacks[fnftToken]
        );
        if (_paybacks[fnftToken] == 0) _fnftTokens.push(fnftToken);

        console.log(
            "addFNFTTokenPayback: after _fnftTokens.length = ",
            _fnftTokens.length
        );
        _paybacks[fnftToken] += payback_;
        console.log(
            "addFNFTTokenPayback: after _paybacks[fnftToken] = ",
            _paybacks[fnftToken]
        );
    }

    function removeFNFTTokenPayback(
        address fnftToken,
        uint256 payback_
    ) external override {
        require(
            _paybacks[fnftToken] >= payback_,
            "Payback must remain zero or more."
        );
        _paybacks[fnftToken] -= payback_;

        if (_paybacks[fnftToken] == 0) _removeFNFTTokenPayback(fnftToken);
    }

    function _removeFNFTTokenPayback(address fnftToken) private {
        require(_paybacks[fnftToken] == 0, "Cannot remove non-zero payback.");

        for (uint256 i = 0; i < _fnftTokens.length; i++)
            if (_fnftTokens[i] == fnftToken) {
                _fnftTokens[i] = _fnftTokens[_fnftTokens.length - 1];
                _fnftTokens.pop();
                break;
            }
    }

    function setApprovalsForAll(
        address[] memory operators,
        address[] memory holders,
        uint256 id,
        bool approved
    ) public {
        require(
            this.balanceOf(msg.sender, id) > 0,
            "Caller is not an owner of the NFT"
        );

        for (uint256 i = 0; i < operators.length; i++) {
            // Approve all the tiptoken contracts as operators for nft
            (bool success, ) = address(this).delegatecall(
                abi.encodeWithSignature(
                    "setApprovalForAll(address,bool)",
                    operators[i],
                    approved
                )
            );
            require(success, "Unable to approve all given tiptoken contracts");

            // // Approve nft for tipping from tiptoken contracts
            // ITipToken(operators[i]).setApprovalForNFT(
            //     holders,
            //     address(this),
            //     id,
            //     approved
            // );
        }
    }
}
