// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

interface IGoldStakeVault {
    function totalSupply() external view returns (uint256);
    function notifyRewardAmount(uint256 rewardAmount) external;
    function mintStake(uint256 amount, address staker) external returns(bool);
    function withdrawGold(uint256 entryId) external returns(bool);
}