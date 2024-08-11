// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.7.0 <0.9.0;

interface IFNFTPayback {
    /**
        @notice The fractional token contract addresses
    */
    function fnftTokens() external view returns (address[] memory);

    /**
        @notice The ratio to payback to fractional NFT of address `FNFTTokenAddress`
    */
    function payback(address fnftToken) external view returns (uint256);

    function addFNFTTokenPayback(address fnftToken, uint256 payback) external;

    function removeFNFTTokenPayback(address fnftToken, uint256 payback)
        external;
}
