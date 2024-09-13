// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02, IV1SwapRouter} from "./interfaces/ISwapRouter02.sol";
import {ICompetition} from "./interfaces/ICompetition.sol";
import {IWSEI} from "./interfaces/IWSEI.sol";

import {Utils} from "./libraries/Utils.sol";

import {Multicall} from "./base/Multicall.sol";

import {Ownable} from "@openzeppelin/contracts@5.0.2/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract Competition is ICompetition, Ownable, Multicall {
    using SafeERC20 for IERC20;

    mapping(address addr => Account acc) public accounts;
    mapping(address addr => uint256 id) public swapTokenIds;
    address[] public swapTokens;

    address payable public immutable mainToken;
    ISwapRouter02 public immutable router;
    bool public immutable acceptNative;

    constructor(address _router, address payable _mainToken, address[] memory _swapTokens) Ownable(msg.sender) {
        Utils._isContract(_router);
        Utils._isContract(_mainToken);
        router = ISwapRouter02(_router);
        mainToken = _mainToken;
        // WSEI check
        if (_mainToken == 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7) acceptNative = true;

        // "firstslotplaceholder" in hex
        swapTokens.push(0x6669727374736C6f74706C616365686f6c646572);

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
            if (_token != mainToken && !isSwapToken(_token)) {
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
            if (isSwapToken(_token)) {
                uint256 id = swapTokenIds[_token];
                address lastToken = swapTokens[--length];
                swapTokens[id] = lastToken;
                swapTokenIds[lastToken] = id;
                swapTokens.pop();
                delete swapTokenIds[_token];
                emit SwapTokenRemoved(_token);
            }
        }
    }

    function deposit() public payable {
        if (acceptNative) payable(mainToken).transfer(msg.value);
        else revert CannotDepositNative();
        _noteDeposit(msg.value);
    }

    function deposit(uint256 amount) external {
        IERC20(mainToken).safeTransferFrom(msg.sender, address(this), amount);
        _noteDeposit(amount);
    }

    function withdraw(uint256 amount, bool unwrapIfNative) external {
        if (accounts[msg.sender].base < amount) revert InsufficientBalance();
        if (unwrapIfNative && acceptNative) {
            IWSEI(mainToken).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(mainToken).safeTransfer(msg.sender, amount);
        }

        accounts[msg.sender].base -= amount;
        emit NewWithdrawal(msg.sender, amount);
    }

    /// @inheritdoc IV1SwapRouter
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        payable
        /*returns (uint256 amountOut)*/ {
        // check balance before swap
        _validateRoute(path[0], path[path.length - 1]);
        router.swapExactTokensForTokens(amountIn, amountOutMin, path, to);
        // note down balance changes
    }

    /// @inheritdoc IV1SwapRouter
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        external
        payable
        /*returns (uint256 amountIn)*/ {
        // check balance before swap
        _validateRoute(path[0], path[path.length - 1]);
        router.swapTokensForExactTokens(amountIn, amountInMax, path, to);
        // note down balance changes
    }

    function _noteDeposit(uint256 amount) private {
        accounts[msg.sender].base += amount;
        emit NewDeposit(msg.sender, amount);
    }

    function _validateRoute(address _tokenIn, address _tokenOut) public view {
        if ((_tokenIn != mainToken || !isSwapToken(_tokenIn)) && (_tokenOut != mainToken || !isSwapToken(_tokenOut))) revert InvalidRoute();
    }

    function isSwapToken(address _token) public view returns (bool) {
        return swapTokenIds[_token] > 0;
    }

    receive() external payable {
        deposit();
    }
}
