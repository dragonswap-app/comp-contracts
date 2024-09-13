// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface ICompetition {
    struct Account {
        uint256 base;
        uint256 earnings;
    }

    event SwapTokenAdded(address token);
    event SwapTokenRemoved(address token);
    event NewDeposit(address account, uint256 amount);
    event NewWithdrawal(address account, uint256 amount);

    error CannotDepositNative();
    error InsufficientBalance();
    error InvalidRoute();
}
