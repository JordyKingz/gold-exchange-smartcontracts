// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./Entry.sol";

struct Staker {
    uint totalStaked; // total amount of tokens staked
    uint[] entryIndexer; // list of stake entries id
    mapping(uint => Entry) entries; // staking entries
    uint rewardCallableDate;
}
