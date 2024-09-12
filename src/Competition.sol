// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./interfaces/ICompetition.sol";
import "./interfaces/IWSEI.sol";

import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract Competition is ICompetition, Ownable {
    using SafeERC20 for IERC20;

    mapping(address addr => Account acc) public accounts;
    mapping(address addr => uint256 id) public swapTokenIds;
    address[] public swapTokens;

    address public immutable mainToken;
    bool public immutable acceptSei;

    constructor(address _mainToken) Ownable(msg.sender) {
        _checkToken(_mainToken);
        // WSEI check
        if (_mainToken == 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7) acceptSei = true;
        mainToken = _mainToken;
        // "firstslotplaceholder" in hex
        swapTokens.push(0x6669727374736C6f74706C616365686f6c646572);
    }

    function addSwapTokens(address[] calldata _swapTokens) external onlyOwner {
        // Gas opt
        uint256 _length = _swapTokens.length;
        uint256 length = swapTokens.length;
        for (uint256 i; i < _length; ++i) {
            address _token = _swapTokens[i];
            _checkToken(_token);
            if (_token == mainToken) revert();
            if (isSwapToken(_token)) revert();
            swapTokenIds[_token] = length++;
            swapTokens.push(_token);
            //emit event
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
                address lastToken = swapTokens[length--];
                swapTokens[id] = lastToken;
                swapTokenIds[lastToken] = id;
                swapTokens.pop();
                delete swapTokenIds[_token];
                // emit event
            }
        }
    }

    function deposit() public payable {
        if (acceptSei) payable(mainToken).transfer(msg.value);
        else revert();
        _updateAccount(msg.value);
    }

    function deposit(uint256 amount) external {
        IERC20(mainToken).safeTransferFrom(msg.sender, address(this), amount);
        _updateAccount(amount);
    }

    function swap(uint256 _tokenIn, uint256 _tokenOut, uint24 fee) external {
        _validateRoute(_tokenIn, _tokenOut);
        if (fee == 0) {
            // v2 swap
        } else {
            // v3 swap with pool of specified fee
        }
    }

    function withdraw(uint256 amount, bool SEI) external {
        //either
        // IWSEI(_mainToken).withdraw(amount)
        // deduct from balance
        // send sei: payable(msg.sender).send(amount);
        // or
        // deduct from balance
        // IERC20(_mainToken).safeTransfer(msg.sender, amount);
    }

    function _updateAccount(uint256 amount) private {
        accounts[msg.sender].base += amount;
    }

    function _checkToken(address _token) private view {
        // solhint-disable-next-line
        assembly {
            // If address contains no code - revert (substitues address zero check)
            if iszero(extcodesize(_token)) { revert(0, 0) }
        }
    }

    function _validateRoute(address _tokenIn, address _tokenOut) public view {
        address _mainToken = mainToken;
        if ((_tokenIn == _mainToken && isSwapToken(_tokenOut)) || (isSwapToken(_tokenIn) && _tokenOut == _mainToken)) {
            // do not revert
        }
    }

    function isSwapToken(address _token) public view returns (bool) {
        return swapTokenIds[_token] > 0;
    }

    receive() external payable {
        deposit();
    }
}
