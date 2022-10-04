// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IWETHGateway{
    function depositETH(address pool, address onBehalfOf, uint16 referralCode) external payable;

    function withdrawETH(address pool, uint256 amount, address to) external;
}