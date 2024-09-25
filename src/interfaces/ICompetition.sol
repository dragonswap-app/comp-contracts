// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02Minimal} from "./ISwapRouter02Minimal.sol";

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
        address _owner,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _router,
        address _usdc,
        address _usdt,
        address[] memory _swapTokens
    ) external;

    /**
     * @param _stable0 if true means stable0 is being deposited else stable1
     */
    function deposit(bool _stable0, uint256 amount) external;

    /**
     * @dev Function to exit the competition
     * After exit, all tokens need to be withdrawn in order to re-join.
     */
    function exit() external;
    /**
     * @dev To be added.
     */
    function addSwapTokens(address[] memory _swapTokens) external;

    /**
     * @dev Router
     */
    function router() external view returns (ISwapRouter02Minimal);

    /**
     * @dev Stable coin which can be directly deposited
     */
    function stable0() external view returns (address);

    /**
     * @dev Stable coin which can be directly deposited
     */
    function stable1() external view returns (address);

    /**
     * @dev Timestamp at which the competition begins
     */
    function startTimestamp() external view returns (uint256);
    /**
     * @dev Timestamp at which the competition ends
     */
    function endTimestamp() external view returns (uint256);

    /**
     * @dev All tokens that are swappable during competition
     */
    function swapTokens(uint256 id) external view returns (address);
    /**
     * @dev To be added.
     */
    function isOut(address account) external view returns (bool);

     /**
     * @dev To be added.
     */
    function swapTokenIds(address addr) external view returns (uint256);
    /**
     * @dev To be added.
     */
    function balances(address account, address token) external view returns (uint256);
    /**
     * @dev To be added.
     */
    function MINIMAL_DEPOSIT() external pure returns (uint256);
    /**
     * @dev To be added.
     */
    function isSwapToken(address _token) external view returns (bool);
}
