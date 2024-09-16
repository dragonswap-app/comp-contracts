// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02, IV1SwapRouter} from "./ISwapRouter02.sol";

interface ICompetition is IV1SwapRouter {
    struct Account {
        uint256 base;
        uint256 earnings;
        mapping(address token => uint256 balance) balances;
    }

    enum SwapType {
        V1,
        V2
    }

    event SwapTokenAdded(address token);
    event SwapTokenRemoved(address token);
    event NewDeposit(address indexed account, uint256 amount);
    event NewWithdrawal(address indexed account, uint256 amount);
    event NewSwap(
        address indexed account,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        SwapType swap
    );

    error CannotDepositNative();
    error InsufficientBalance();
    error InvalidRoute();
}
