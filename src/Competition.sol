// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02Minimal, IV1SwapRouter, IV2SwapRouter} from "./interfaces/ISwapRouter02Minimal.sol";
import {ICompetition} from "./interfaces/ICompetition.sol";

import {Utils} from "./libraries/Utils.sol";

import {Multicall} from "./base/Multicall.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.2/access/OwnableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract Competition is ICompetition, ISwapRouter02Minimal, OwnableUpgradeable, Multicall {
    using SafeERC20 for IERC20;

    ISwapRouter02Minimal public router;
    address public stable0;
    address public stable1;
    uint256 public startTimestamp;
    uint256 public endTimestamp;

    address[] public swapTokens;

    mapping(address addr => bool exited) public isOut;
    mapping(address addr => uint256 id) public swapTokenIds;
    mapping(address addr => mapping(address token => uint256 balance)) public balances;

    uint256 public constant MINIMAL_DEPOSIT = 10e6;

    modifier onceOn() {
        _isOnCheck();
        _;
    }

    modifier notOut() {
        _isNotOutCheck();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _router,
        address _stable0,
        address _stable1,
        address[] memory _swapTokens
    ) external initializer {
        __Ownable_init(_owner);

        if (_startTimestamp < block.timestamp || _endTimestamp < _startTimestamp + 1 days) revert();
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;

        Utils._isContract(_router);
        Utils._isContract(_stable0);
        Utils._isContract(_stable1);

        router = ISwapRouter02Minimal(_router);
        stable0 = _stable0;
        stable1 = _stable1;

        // "firstslotplaceholder" in hex
        swapTokens.push(0x6669727374736C6f74706C616365686f6c646572);

        swapTokens.push(_stable0);
        swapTokenIds[_stable0] = 1;
        swapTokens.push(_stable1);
        swapTokenIds[_stable0] = 2;

        // Add swap tokens
        _addSwapTokens(_swapTokens);
    }

    /**
     * @param _stable0 if true means stable0 is being deposited else stable1
     */
    function deposit(bool _stable0, uint256 amount) external notOut {
        if (block.timestamp > endTimestamp) revert Ended();
        if (amount < MINIMAL_DEPOSIT) revert InsufficientAmount();
        address stable = _stable0 ? stable0 : stable1;
        IERC20(stable).safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender][stable] += amount;
        emit NewDeposit(msg.sender, stable, amount);
    }

    function exit() external {
        uint256 length = swapTokens.length;
        bool madeWithdrawal;
        bool leftoverExists;
        for (uint256 i; i < length; i++) {
            address token = swapTokens[i];
            uint256 balance = balances[msg.sender][token];
            if (balance > 0) {
                (bool success,) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, balance));
                if (success) {
                    delete balances[msg.sender][token];
                    madeWithdrawal = true;
                } else {
                    leftoverExists = true;
                }
            }
        }
        if (madeWithdrawal && !isOut[msg.sender]) {
            isOut[msg.sender] = true;
            emit Exit(msg.sender);
        }
        if (!leftoverExists) {
            isOut[msg.sender] = false;
        }
    }

    /// @inheritdoc IV1SwapRouter
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address /*to*/ )
        external
        payable
        onceOn
        notOut
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
        onceOn
        notOut
        returns (uint256 amountIn)
    {
        address _tokenIn = path[0];
        address _tokenOut = path[path.length - 1];
        _validateSwapAndApprove(_tokenIn, _tokenOut, amountInMax);
        amountIn = router.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
        IERC20(_tokenIn).approve(address(router), 0);
        _noteSwap(_tokenIn, _tokenOut, amountIn, amountOut, SwapType.V1);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        onceOn
        notOut
        returns (uint256 amountOut)
    {
        address _tokenIn = params.tokenIn;
        address _tokenOut = params.tokenOut;
        uint256 _amountIn = params.amountIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        amountOut = router.exactInputSingle(params);
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInput(ExactInputParams calldata params) external payable onceOn notOut returns (uint256 amountOut) {
        bytes memory path = params.path;
        address _tokenIn = Utils._toAddress(path, 0);
        address _tokenOut = Utils._toAddress(path, path.length - 20);
        uint256 _amountIn = params.amountIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        amountOut = router.exactInput(params);
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        onceOn
        notOut
        returns (uint256 amountIn)
    {
        address _tokenOut = params.tokenOut;
        address _tokenIn = params.tokenIn;
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        amountIn = router.exactOutputSingle(params);
        IERC20(_tokenIn).approve(address(router), 0);
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutput(ExactOutputParams calldata params) external payable onceOn notOut returns (uint256 amountIn) {
        bytes memory path = params.path;
        address _tokenIn = Utils._toAddress(path, 0);
        address _tokenOut = Utils._toAddress(path, path.length - 20);
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        amountIn = router.exactOutput(params);
        IERC20(_tokenIn).approve(address(router), 0);
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    function addSwapTokens(address[] memory _swapTokens) public onlyOwner {
        _addSwapTokens(_swapTokens);
    }

    function isSwapToken(address _token) public view returns (bool) {
        return swapTokenIds[_token] > 0;
    }

    function _addSwapTokens(address[] memory _swapTokens) private {
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

    /**
     * @dev Function to validate swap parameters and prepare state for a swap.
     */
    function _validateSwapAndApprove(address _tokenIn, address _tokenOut, uint256 _amountIn) private {
        // Ensure that both _tokenIn and _tokenOut are swappable inside the competition.
        if (!isSwapToken(_tokenIn) && !isSwapToken(_tokenOut)) {
            revert InvalidRoute();
        }
        // Ensure that the competition participant has sufficient amount of tokens.
        if (balances[msg.sender][_tokenIn] < _amountIn) revert InsufficientBalance();
        // Approve specified token amount to the router.
        IERC20(_tokenIn).approve(address(router), _amountIn);
        // Decrease _tokenIn balance.
        balances[msg.sender][_tokenIn] -= _amountIn;
    }

    /**
     * @dev Function to note down balance change after swap and emit an event with relevant information.
     */
    function _noteSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut, SwapType _swap)
        private
    {
        // Increase _tokenOut balance.
        balances[msg.sender][_tokenOut] += _amountOut;
        // Emit event.
        emit NewSwap(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut, _swap);
    }

    /**
     * @dev Ensure that the competition is in progress.
     */
    function _isOnCheck() private view {
        if (block.timestamp < startTimestamp) revert NotOnYet();
    }

    /**
     * @dev Ensure that caller is not in the process of leaving the competition.
     */
    function _isNotOutCheck() private view {
        if (isOut[msg.sender]) revert AlreadyLeft();
    }
}
