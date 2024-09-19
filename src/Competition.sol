// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02Minimal, IV1SwapRouter, IV2SwapRouter} from "./interfaces/ISwapRouter02Minimal.sol";
import {ICompetition} from "./interfaces/ICompetition.sol";

import {Utils} from "./libraries/Utils.sol";

import {Multicall} from "./base/Multicall.sol";

import {Ownable} from "@openzeppelin/contracts@5.0.2/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract Competition is ICompetition, ISwapRouter02Minimal, Ownable, Multicall {
    using SafeERC20 for IERC20;

    mapping(address addr => mapping(address token => uint256 balance)) public balances;
    mapping(address addr => uint256 id) public swapTokenIds;
    address[] public swapTokens;

    address public immutable usdc;
    address public immutable usdt;

    ISwapRouter02Minimal public immutable router;
    bool public immutable acceptNative;

    constructor(address _router, address _usdc, address _usdt, address[] memory _swapTokens) Ownable(msg.sender) {
        Utils._isContract(_router);
        Utils._isContract(_usdc);
        Utils._isContract(_usdt);

        router = ISwapRouter02Minimal(_router);
        usdc = _usdc;
        usdt = _usdt;

        // "firstslotplaceholder" in hex
        swapTokens.push(0x6669727374736C6f74706C616365686f6c646572);

        swapTokens.push(_usdc);
        swapTokenIds[_usdc] = 1;
        swapTokens.push(_usdt);
        swapTokenIds[_usdc] = 2;

        // Add swap tokens
        addSwapTokens(_swapTokens);
    }

    function addSwapTokens(address[] memory _swapTokens) public onlyOwner {
        // Gas opt
        uint256 _length = _swapTokens.length;
        uint256 length = swapTokens.length;
        for (uint256 i; i < _length; ++i) {
            address _token = _swapTokens[i];
            Utils._isContract(_token);
            if (!isSwapToken(_token)) {
                swapTokenIds[_token] = length++;
                swapTokens.push(_token);
                emit SwapTokenAdded(_token);
            }
        }
    }

    function removeSwapTokens(address[] calldata _swapTokens) external onlyOwner {
        // If we remove some tokens we should pay attention to let users swap back from these tokens, but not to
        uint256 _length = _swapTokens.length;
        uint256 length = swapTokens.length;
        for (uint256 i; i < _length; ++i) {
            address _token = _swapTokens[i];
            uint256 id = swapTokenIds[_token];
            // Id is checked to be greater than 2 because we do not want to remove placeholder usdc and usdt
            if (isSwapToken(_token) && id > 2) {
                address lastToken = swapTokens[--length];
                swapTokens[id] = lastToken;
                swapTokenIds[lastToken] = id;
                swapTokens.pop();
                delete swapTokenIds[_token];
                emit SwapTokenRemoved(_token);
            }
        }
    }

    /**
     * @param _usdc if true means usdc is being deposited else usdt
     */
    function deposit(bool _usdc, uint256 amount) external {
        address stable = _usdc ? usdc : usdt;
        IERC20(stable).safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender][stable] += amount;
        emit NewDeposit(msg.sender, stable, amount);
    }

    /**
     * @dev Withdraw specified amount of one of the stables
     * Send any number higher than or equal to user balance to withdraw the full balance
     */
    function withdraw(bool _usdc, uint256 amount) public {
        address stable = _usdc ? usdc : usdt;
        if (balances[msg.sender][stable] < amount) amount = balances[msg.sender][stable];
        if (amount > 0) {
            IERC20(stable).safeTransfer(msg.sender, amount);
            balances[msg.sender][stable] -= amount;
            emit NewWithdrawal(msg.sender, stable, amount);
        }
    }

    /**
     * @dev Withdraw specified amount of both of the stables
     * Send any number higher than or equal to user balance to withdraw the full balance
     */
    function withdraw(uint256 amountUsdc, uint256 amountUsdt) external {
        withdraw(true, amountUsdc);
        withdraw(false, amountUsdt);
    }

    /// @inheritdoc IV1SwapRouter
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address /*to*/ )
        external
        payable
        returns (uint256 amountOut)
    {
        // check balance before swap
        address _tokenIn = path[0];
        address _tokenOut = path[path.length - 1];
        _validateSwapAndApprove(_tokenIn, _tokenOut, amountIn);
        amountOut = router.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this));
        // note down balance changes
        _noteSwap(_tokenIn, _tokenOut, amountIn, amountOut, SwapType.V1);
    }

    /// @inheritdoc IV1SwapRouter
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address /*to*/ )
        external
        payable
        returns (uint256 amountIn)
    {
        // check balance before swap
        address _tokenIn = path[0];
        address _tokenOut = path[path.length - 1];
        _validateSwapAndApprove(_tokenIn, _tokenOut, amountInMax);
        amountIn = router.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
        IERC20(_tokenIn).approve(address(router), 0);
        // note down balance changes
        _noteSwap(_tokenIn, _tokenOut, amountIn, amountOut, SwapType.V1);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        // check balance before swap
        address _tokenIn = params.tokenIn;
        address _tokenOut = params.tokenOut;
        uint256 _amountIn = params.amountIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        amountOut = router.exactInputSingle(params);
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut) {
        bytes memory path = params.path;
        address _tokenIn = Utils._toAddress(path, 0);
        address _tokenOut = Utils._toAddress(path, path.length - 20);
        uint256 _amountIn = params.amountIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        amountOut = router.exactInput(params);
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn) {
        // check balance before swap
        address _tokenOut = params.tokenOut;
        address _tokenIn = params.tokenIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        amountIn = router.exactOutputSingle(params);
        IERC20(_tokenIn).approve(address(router), 0);
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn) {
        // check balance before swap
        bytes memory path = params.path;
        address _tokenIn = Utils._toAddress(path, 0);
        address _tokenOut = Utils._toAddress(path, path.length - 20);
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        amountIn = router.exactOutput(params);
        IERC20(_tokenIn).approve(address(router), 0);
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    function _validateSwapAndApprove(address _tokenIn, address _tokenOut, uint256 _amountIn) private {
        if (!isSwapToken(_tokenIn) && !isSwapToken(_tokenOut)) {
            revert InvalidRoute();
        }
        if (balances[msg.sender][_tokenIn] < _amountIn) revert InsufficientBalance();
        IERC20(_tokenIn).approve(address(router), _amountIn);
        balances[msg.sender][_tokenIn] -= _amountIn;
    }

    function _noteSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut, SwapType _swap)
        private
    {
        balances[msg.sender][_tokenOut] += _amountOut;
        emit NewSwap(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut, _swap);
    }

    function isSwapToken(address _token) public view returns (bool) {
        return swapTokenIds[_token] > 0;
    }

    function dragonswapV2SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {}
}
