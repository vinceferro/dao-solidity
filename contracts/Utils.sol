// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title NftMarketplace
 * @author TheV
 */
interface NftMarketplace {
    function getPrice(address nftContract, uint nftId) external returns (uint price);
    function buy(address nftContract, uint nftId) external payable returns (bool success);
}