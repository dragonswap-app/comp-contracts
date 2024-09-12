// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";

interface IWSEI is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    receive() external payable;
}
