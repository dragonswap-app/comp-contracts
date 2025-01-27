// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter02Minimal, IV1SwapRouter, IV2SwapRouter} from "./interfaces/ISwapRouter02Minimal.sol";
import {ICompetition} from "./interfaces/ICompetition.sol";

import {Utils} from "./libraries/Utils.sol";

import {Multicall} from "./base/Multicall.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.2/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable@5.0.2/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.2/utils/PausableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/IERC20Metadata.sol";

contract Competition is
    ICompetition,
    ISwapRouter02Minimal,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    Ownable2StepUpgradeable,
    Multicall
{
    using SafeERC20 for IERC20;

    /// @inheritdoc ICompetition
    ISwapRouter02Minimal public router;

    /// @inheritdoc ICompetition
    uint256 public startTimestamp;
    /// @inheritdoc ICompetition
    uint256 public endTimestamp;

    /// @inheritdoc ICompetition
    address[] public swapTokens;

    /// @inheritdoc ICompetition
    mapping(address stable => bool isAllowed) public stableCoins;
    /// @inheritdoc ICompetition
    mapping(address account => bool exited) public isOut;
    /// @inheritdoc ICompetition
    mapping(address swapToken => uint256 id) public swapTokenIds;
    /// @inheritdoc ICompetition
    mapping(address account => mapping(address token => uint256 balance)) public balances;

    modifier onceOn() {
        _isOnCheck();
        _;
    }

    modifier notOut() {
        _isNotOutCheck();
        _;
    }

    // Disable initializers on implementation.
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ICompetition
    function initialize(
        address owner_,
        uint256 startTimestamp_,
        uint256 endTimestamp_,
        address router_,
        address[] calldata stableCoins_,
        address[] calldata swapTokens_
    ) external initializer {
        // Initialize OwnableUpgradeable
        __Ownable_init(owner_);
        __ReentrancyGuard_init();

        // Ensure the validity of the timestamps.
        if (startTimestamp_ < block.timestamp || endTimestamp_ < startTimestamp_ + 1 days) revert InvalidTimestamps();

        // Ensure code is present at the specified addresses.
        Utils._isContract(router_);

        // Store values.
        router = ISwapRouter02Minimal(router_);
        startTimestamp = startTimestamp_;
        endTimestamp = endTimestamp_;

        // This helps us avoid zero value being a swapToken id.
        swapTokens.push(address(0xdead));

        // Add stables to the swapTokens structure and whitelist them for deposit.
        // They're added in order to simplify the swap route check.
        _addSwapTokens(stableCoins_, true);

        // Add swap tokens.
        _addSwapTokens(swapTokens_, false);
    }

    /// @inheritdoc ICompetition
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc ICompetition
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ICompetition
    function deposit(address stableCoin, uint256 amount) external notOut whenNotPaused {
        // Ensure competition is in progress (users can deposit before beginning).
        if (block.timestamp > endTimestamp) revert Ended();
        // Ensure minimum deposit is reached (10 stablecoins).
        if (amount < 10 * 10 ** IERC20Metadata(stableCoin).decimals()) revert InsufficientAmount();
        // Ensure stable coin is approved.
        if (!stableCoins[stableCoin]) revert InvalidDepositToken();
        // Make the deposit.
        IERC20(stableCoin).safeTransferFrom(msg.sender, address(this), amount);
        // Note the balance change.
        balances[msg.sender][stableCoin] += amount;
        // Emit event.
        emit NewDeposit(msg.sender, stableCoin, amount);
    }

    /// @inheritdoc ICompetition
    function exit() external nonReentrant {
        uint256 length = swapTokens.length;
        // Flag for withdrawal of any amount of any token being made.
        bool madeWithdrawal;
        // Flag for leftover existence (occurs when a token is stuck).
        bool leftoverExists;
        for (uint256 i; i < length; ++i) {
            // Retrieve values.
            address token = swapTokens[i];
            uint256 balance = balances[msg.sender][token];
            if (balance > 0) {
                // Try to transfer tokens.
                (bool success, bytes memory returndata) =
                    token.call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, balance));
                // Support non-standard tokens that do not fail on transfer
                if (success && (returndata.length == 0 || abi.decode(returndata, (bool)))) {
                    // Delete user balance for the withdrawn token and mark flag.
                    delete balances[msg.sender][token];
                    madeWithdrawal = true;
                } else {
                    leftoverExists = true;
                }
            }
        }
        // If user made a withdrawal and is not marked with isOut flag, mark him as being in exit process.
        if (madeWithdrawal && !isOut[msg.sender]) {
            isOut[msg.sender] = true;
            emit Exit(msg.sender);
        }
        // If there is no leftover, delete the isOut mark, then user can safely rejoin the competition.
        if (!leftoverExists) {
            isOut[msg.sender] = false;
        }
    }

    /// @inheritdoc IV1SwapRouter
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address /*to*/ )
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
        // Check path.
        uint256 pathLength = path.length;
        if (pathLength < 2) revert InvalidPathLength();
        // Retrieve tokens.
        address _tokenIn = path[0];
        address _tokenOut = path[pathLength - 1];
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, amountIn);
        // Perform a swap.
        amountOut = router.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this));
        // note down balance changes.
        _noteSwap(_tokenIn, _tokenOut, amountIn, amountOut, SwapType.V1);
    }

    /// @inheritdoc IV1SwapRouter
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address /*to*/ )
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountIn)
    {
        // Check path.
        uint256 pathLength = path.length;
        if (pathLength < 2) revert InvalidPathLength();
        // Retrieve tokens.
        address _tokenIn = path[0];
        address _tokenOut = path[pathLength - 1];
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, amountInMax);
        // Perform a swap.
        amountIn = router.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
        // Nullify allowance.
        IERC20(_tokenIn).forceApprove(address(router), 0);
        // Note swap state changes.
        _noteSwap(_tokenIn, _tokenOut, amountIn, amountOut, SwapType.V1);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInputSingle(ExactInputSingleParams memory params)
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
        // Retrieve swap data.
        address _tokenIn = params.tokenIn;
        address _tokenOut = params.tokenOut;
        uint256 _amountIn = params.amountIn;
        // Override recipient.
        params.recipient = address(this);
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        // Perform a swap.
        amountOut = router.exactInputSingle(params);
        // Note swap state changes.
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactInput(ExactInputParams memory params)
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
        // Check path.
        bytes memory path = params.path;
        _pathLengthCheck(path);
        // Retrieve swap data.
        (address _tokenIn, address _tokenOut) = _getTokensFromV2Path(path);
        uint256 _amountIn = params.amountIn;
        // Override recipient.
        params.recipient = address(this);
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, _amountIn);
        // Perform a swap.
        amountOut = router.exactInput(params);
        // Note swap state changes.
        _noteSwap(_tokenIn, _tokenOut, _amountIn, amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutputSingle(ExactOutputSingleParams memory params)
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountIn)
    {
        // Retrieve tokens.
        address _tokenOut = params.tokenOut;
        address _tokenIn = params.tokenIn;
        // Override recipient.
        params.recipient = address(this);
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        // Perfrom a swap.
        amountIn = router.exactOutputSingle(params);
        // Nullify allowance.
        IERC20(_tokenIn).forceApprove(address(router), 0);
        // Note swap state changes.
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    /// @inheritdoc IV2SwapRouter
    function exactOutput(ExactOutputParams memory params)
        external
        onceOn
        notOut
        whenNotPaused
        nonReentrant
        returns (uint256 amountIn)
    {
        // Check path.
        bytes memory path = params.path;
        _pathLengthCheck(path);
        // Retrieve tokens.
        (address _tokenOut, address _tokenIn) = _getTokensFromV2Path(path);
        // Override recipient.
        params.recipient = address(this);
        // Validate swap parameters and approve tokens.
        _validateSwapAndApprove(_tokenIn, _tokenOut, params.amountInMaximum);
        // Perfrom a swap.
        amountIn = router.exactOutput(params);
        // Nullify allowance.
        IERC20(_tokenIn).forceApprove(address(router), 0);
        // Note swap state changes.
        _noteSwap(_tokenIn, _tokenOut, amountIn, params.amountOut, SwapType.V2);
    }

    /// @inheritdoc ICompetition
    function addSwapTokens(address[] calldata swapTokens_, bool stableCoins_) external onlyOwner {
        _addSwapTokens(swapTokens_, stableCoins_);
    }

    /// @inheritdoc ICompetition
    function isSwapToken(address token) public view returns (bool isToken) {
        // Token having an id implies that it is added to the swapTokens array.
        isToken = swapTokenIds[token] > 0;
    }

    /**
     * @dev Function to whitelist swap tokens and stablecoins.
     */
    function _addSwapTokens(address[] calldata _swapTokens, bool _stableCoins) private {
        // Gas opt
        uint256 _length = _swapTokens.length;
        uint256 length = swapTokens.length;
        for (uint256 i; i < _length; ++i) {
            address _token = _swapTokens[i];
            // Ensure there is code at the specified address
            Utils._isContract(_token);
            if (_stableCoins) {
                stableCoins[_token] = true;
                emit StableCoinAdded(_token);
            }
            // Add token if it is not already present
            if (!isSwapToken(_token)) {
                swapTokenIds[_token] = length++;
                swapTokens.push(_token);
                emit SwapTokenAdded(_token);
            } else {
                revert AlreadyAdded(_token);
            }
        }
    }

    /**
     * @dev Function to retrieve first and last token from a V2 path.
     * @param path is a V2 path byte-string.
     */
    function _getTokensFromV2Path(bytes memory path) private pure returns (address firstToken, address lastToken) {
        firstToken = Utils._toAddress(path, 0);
        lastToken = Utils._toAddress(path, path.length - 20);
    }

    /**
     * @dev Function to validate swap parameters and prepare state for a swap.
     */
    function _validateSwapAndApprove(address _tokenIn, address _tokenOut, uint256 _amountIn) private {
        // Check input amount.
        if (_amountIn == 0) revert InvalidAmountIn();
        // Ensure that both _tokenIn and _tokenOut are swappable inside the competition.
        if (!isSwapToken(_tokenIn) || !isSwapToken(_tokenOut)) {
            revert InvalidRoute();
        }
        if (_tokenIn == _tokenOut) revert CannotSwapSame();
        // Ensure that the competition participant has sufficient amount of tokens.
        if (balances[msg.sender][_tokenIn] < _amountIn) revert InsufficientBalance();
        // Approve specified token amount to the router.
        IERC20(_tokenIn).forceApprove(address(router), _amountIn);
    }

    /**
     * @dev Function to note down balance change after swap and emit an event with relevant information.
     */
    function _noteSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut, SwapType _swapType)
        private
    {
        // Decrease _tokenIn balance
        balances[msg.sender][_tokenIn] -= _amountIn;
        // Increase _tokenOut balance.
        balances[msg.sender][_tokenOut] += _amountOut;
        // Emit event.
        emit NewSwap(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut, _swapType);
    }

    /**
     * @dev Ensure that the competition is in progress.
     */
    function _isOnCheck() private view {
        if (block.timestamp < startTimestamp) revert NotOnYet();
        if (block.timestamp > endTimestamp) revert IsEnded();
    }

    /**
     * @dev Ensure that caller is not in the process of leaving the competition.
     */
    function _isNotOutCheck() private view {
        if (isOut[msg.sender]) revert AlreadyLeft();
    }

    /**
     * @dev Path consists of addresses and fees (like: addr + fee + addr + fee),
     * therefore in order to contain a single swap path should be at least 43 bytes long (2 addresses + uint24 fee).
     * The other check ensures path length fits the format.
     */
    function _pathLengthCheck(bytes memory path) private pure {
        if (path.length < 43 || (path.length - 20) % 23 != 0) revert InvalidPathLength();
    }
}
