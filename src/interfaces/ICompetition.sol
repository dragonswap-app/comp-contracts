// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02Minimal} from "./ISwapRouter02Minimal.sol";

interface ICompetition {
    enum SwapType {
        V1,
        V2
    }

    event SwapTokenAdded(address indexed token);
    event StableCoinAdded(address indexed stableCoin);
    event NewDeposit(address indexed account, address indexed stableCoin, uint256 amount);
    event Exit(address indexed account);
    /**
     * @dev Event occurring on every new swap being made.
     * @param account is user account that made the swap.
     * @param tokenIn is the token that user sold.
     * @param tokenOut is the token that user bought.
     * @param amountIn is the amount of tokenIn that was sold.
     * @param amountOut is the amount of tokenOut that was bought.
     * @param swapType is the version of DS protocol that was used to perform the swap, either V1 or V2.
     */
    event NewSwap(
        address indexed account,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        SwapType swapType
    );

    /// @dev User is in the exit process.
    error AlreadyLeft();
    /// @dev Competition already ended.
    error Ended();
    /// @dev Input amount equals zero.
    error InvalidAmountIn();
    /// @dev Insufficient deposit amount.
    error InsufficientAmount();
    /// @dev Insufficient balance to execute a swap.
    error InsufficientBalance();
    /// @dev Invalid swap route (meaning not all tokens are swapTokens).
    error InvalidRoute();
    /// @dev Competition hasn't stated yet (swaps cannot be made before the start).
    error NotOnYet();
    /// @dev Competition has ended (swaps cannot be made after the end).
    error IsEnded();
    /// @dev Invalid start/end timestamp(s) on initialization.
    error InvalidTimestamps();
    /// @dev Invalid path length in both case of an array and byte-string.
    error InvalidPathLength();
    /// @dev Tried to deposit a stable coin which is not whitelisted.
    error InvalidDepositToken();
    /// @dev Means a token has already been added as a swap token.
    error AlreadyAdded(address token);
    /// @dev tokeIn and tokenOut cannot be the same.
    error CannotSwapSame();

    /**
     * @dev Competition contract initialization function.
     * @param owner_ is a contract owner.
     * @param startTimestamp_ is the timestamp at which the competition starts.
     * @param endTimestamp_ is the timestamp at which the competition ends.
     * @param router_ is the SwapRouter02 aggregating the swaps.
     * @param stableCoins_ is an array of stable coins which are acceptable for deposit.
     * @param swapTokens_ is the initial set of swapTokens to be supported.
     */
    function initialize(
        address owner_,
        uint256 startTimestamp_,
        uint256 endTimestamp_,
        address router_,
        address[] memory stableCoins_,
        address[] memory swapTokens_
    ) external;

    /**
     * @dev Function to pause the contract.
     */
    function pause() external;

    /**
     * @dev Function to unpause the contract.
     */
    function unpause() external;

    /**
     * @param stableCoin is an address of a stable coin to deposit.
     */
    function deposit(address stableCoin, uint256 amount) external;

    /**
     * @dev Function to exit the competition
     * After exit, all tokens need to be withdrawn in order to re-join.
     */
    function exit() external;

    /**
     * @dev Function to add a new set of swapTokens to the competition.
     * @param swapTokens_ is an array of swapTokens.
     */
    function addSwapTokens(address[] memory swapTokens_, bool stableCoins_) external;

    /**
     * @dev Function to change the end timestamp of the competition instance.
     */
    function updateEndTimestamp(uint256 timestamp) external;

    /**
     * @dev Router of SwapRouter02 type.
     */
    function router() external view returns (ISwapRouter02Minimal);

    /**
     * @dev See if a stable coin can be deposited.
     */
    function stableCoins(address stableCoin) external view returns (bool);

    /**
     * @dev Timestamp at which the competition begins.
     */
    function startTimestamp() external view returns (uint256);
    /**
     * @dev Timestamp at which the competition ends.
     */
    function endTimestamp() external view returns (uint256);

    /**
     * @dev All tokens that are swappable during competition.
     */
    function swapTokens(uint256 id) external view returns (address);
    /**
     * @dev Hash map / flag which tells us if user is in the exiting process.
     * This flag will be true only while user has made the exit with a piece of his balance
     * meaning other piece is still being present in the Competition contract
     * due to the technical inoperability (one of user's tokens being stuck).
     * This flag prevents users from re-joining before their balance is completely cleared out.
     * Once leftover is withdrawn the flag will also get cleared out and they'll be able to rejoin.
     * @param account is the user account.
     */
    function isOut(address account) external view returns (bool);

    /**
     * @dev Hash map storing ids of swap tokens.
     * If token has an id (id > 0), then it is a swap token.
     * @param token is the token address.
     */
    function swapTokenIds(address token) external view returns (uint256);
    /**
     * @dev Structure storing user balances for each swap token.
     * @param account is user account for which balance is checked.
     * @param token is the token whos balance is checked on the user's account.
     */
    function balances(address account, address token) external view returns (uint256);

    /**
     * @dev Function to determine if an address represents a swap token.
     * @param _token is a token address to check.
     */
    function isSwapToken(address _token) external view returns (bool);
}
