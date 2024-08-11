// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title NFTPlaylist
 * @dev NFTPlaylist is a smart contract that allows the creation and management of playlists composed of NFTs.
 * This contract provides functionality to add, remove, and organize NFTs within a playlist.
 *
 * @notice This contract is part of a system that enables users to create and manage playlists of NFTs,
 * facilitating the organization and display of digital assets and playback of media NFTS.
 */
contract NFTPlaylist {
    struct NFT {
        address contractAddress;
        uint256 tokenId;
    }

    mapping(uint256 => NFT[]) public playlists;
    mapping(uint256 => mapping(address => mapping(uint256 => bool)))
        public playlistNFTs;

    function addNFT(
        uint256 playlistId,
        address _contractAddress,
        uint256 _tokenId
    ) public {
        require(
            !playlistNFTs[playlistId][_contractAddress][_tokenId],
            "NFT already in playlist"
        );

        playlists[playlistId].push(NFT(_contractAddress, _tokenId));
        playlistNFTs[playlistId][_contractAddress][_tokenId] = true;
    }

    function deleteNFT(
        uint256 playlistId,
        address _contractAddress,
        uint256 _tokenId
    ) public {
        require(
            playlistNFTs[playlistId][_contractAddress][_tokenId],
            "NFT not in playlist"
        );

        uint indexToDelete;
        for (uint i = 0; i < playlists[playlistId].length; i++) {
            if (
                playlists[playlistId][i].contractAddress == _contractAddress &&
                playlists[playlistId][i].tokenId == _tokenId
            ) {
                indexToDelete = i;
                break;
            }
        }

        if (indexToDelete < playlists[playlistId].length - 1) {
            playlists[playlistId][indexToDelete] = playlists[playlistId][
                playlists[playlistId].length - 1
            ];
        }
        playlists[playlistId].pop();
        delete playlistNFTs[playlistId][_contractAddress][_tokenId];
    }

    function addNFTs(
        uint256 playlistId,
        address[] memory _contractAddresses,
        uint256[] memory _tokenIds
    ) external {
        require(
            _contractAddresses.length == _tokenIds.length,
            "Arrays must have the same length"
        );
        require(_contractAddresses.length > 0, "Arrays must have lengths > 0");

        for (uint i = 0; i < _contractAddresses.length; i++) {
            addNFT(playlistId, _contractAddresses[i], _tokenIds[i]);
        }
    }

    function deleteNFTs(
        uint256 playlistId,
        address[] memory _contractAddresses,
        uint256[] memory _tokenIds
    ) external {
        require(
            _contractAddresses.length == _tokenIds.length,
            "Arrays must have the same length"
        );
        require(_contractAddresses.length > 0, "Arrays must have lengths > 0");

        for (uint i = 0; i < _contractAddresses.length; i++) {
            deleteNFT(playlistId, _contractAddresses[i], _tokenIds[i]);
        }
    }

    function getPlaylistCount(uint256 playlistId) external view returns (uint) {
        return playlists[playlistId].length;
    }

    function getPlaylist(
        uint256 playlistId
    ) external view returns (NFT[] memory) {
        return playlists[playlistId];
    }
}
