// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";

import {IWSEI} from "../src/interfaces/IWSEI.sol";

import {Competition} from "../src/Competition.sol";

contract CompetitionTest is Test {
    Competition public competition;

    address public constant DS_ROUTER = 0x11DA6463D6Cb5a03411Dbf5ab6f6bc3997Ac7428;
    address public constant USDC = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;
    address payable public constant WSEI = payable(0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7);
    string public constant URL = "https://evm-rpc.sei-apis.com";
    address[] public swapTokens;

    function setUp() public {
        vm.createSelectFork(URL);

        competition = new Competition(DS_ROUTER, WSEI, swapTokens);
    }

    function test_depositViaFunction() public {
        assertEq(IWSEI(WSEI).balanceOf(address(competition)), 0);
        uint256 depositAmount = 1 ether;
        competition.deposit{value: depositAmount}();
        assertEq(IWSEI(WSEI).balanceOf(address(competition)), depositAmount);
    }

    function test_depositDirectly() public {
        assertEq(IWSEI(WSEI).balanceOf(address(competition)), 0);
        uint256 depositAmount = 1 ether;
        (bool success, ) = payable(competition).call{value: depositAmount}("");
        assert(success);
        assertEq(IWSEI(WSEI).balanceOf(address(competition)), depositAmount);
    }

    function test_AddNewSwapToken() public {
        assertEq(competition.isSwapToken(USDC), false);
        swapTokens.push(USDC);
        competition.addSwapTokens(swapTokens);
        assertEq(competition.isSwapToken(USDC), true);
        swapTokens.pop();
    }

    function testFail_AddNewSwapToken_EOA() public {
        swapTokens.push(address(1));
        competition.addSwapTokens(swapTokens);
    }

    //function testFuzz_SetNumber(uint256 x) public {
    //    competition.setNumber(x);
    //    assertEq(competition.number(), x);
    //}
}
