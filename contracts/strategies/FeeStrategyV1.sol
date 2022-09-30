// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/IFeeStrategy.sol";

contract FeeStrategyV1 is IFeeStrategy {
    function calculateAccountFee(
        uint256 reedemTime,
        uint256 lockTime,
        uint256 balance
    ) external view override returns (uint256) {
        if (reedemTime <= block.timestamp) return uint256(0);

        return
            ((reedemTime - block.timestamp) * 50 * balance) / (lockTime * 100);
    }
}
