// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFeeStrategy {
    function calculateAccountFee(
        uint256 reedemTime,
        uint256 lockTime,
        uint256 balance
    ) external view returns (uint256);
}
