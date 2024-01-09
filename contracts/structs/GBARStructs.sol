// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

struct RetrievalRequest {
    address from;
    uint amount;
    uint8 numConfirmations;
    bool executed;
}