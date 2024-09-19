// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IV1SwapRouter, IV2SwapRouter} from "./ISwapRouter02.sol";
//import {IV2SwapRouterNoCallback} from "./IV2SwapRouterNoCallback.sol";

interface ICompetition is IV1SwapRouter, IV2SwapRouter /*IV2SwapRouterNoCallback*/ {
    enum SwapType {
        V1,
        V2
    }

    event SwapTokenAdded(address token);
    event SwapTokenRemoved(address token);
    event NewDeposit(address indexed account, address indexed stable, uint256 amount);
    event NewWithdrawal(address indexed account, address indexed stable, uint256 amount);
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
    error TransferFailed();
}
