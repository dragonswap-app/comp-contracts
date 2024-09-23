// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface ICompetition {
    enum SwapType {
        V1,
        V2
    }

    event SwapTokenAdded(address token);
    event SwapTokenRemoved(address token);
    event NewDeposit(address indexed account, address indexed stable, uint256 amount);
    event Exit(address indexed account);
    event NewSwap(
        address indexed account,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        SwapType swap
    );

    error AlreadyLeft();
    error CannotDepositNative();
    error Ended();
    error InsufficientAmount();
    error InsufficientBalance();
    error InvalidRoute();
    error TransferFailed();
    error NotOnYet();

    function initialize(
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _router,
        address _usdc,
        address _usdt,
        address[] memory _swapTokens
    ) external;
}
