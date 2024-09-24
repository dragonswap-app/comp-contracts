// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ISwapRouter02Minimal} from "../src/interfaces/ISwapRouter02Minimal.sol";
import {Competition} from "../src/Competition.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract CompetitionTest is Test {
    Competition public competition;
    address[] public swapTokens;

    ISwapRouter02Minimal public constant DS_ROUTER = ISwapRouter02Minimal(0x11DA6463D6Cb5a03411Dbf5ab6f6bc3997Ac7428);
    // @dev USDC and USDT are both native sei tokens which means they include precompile interaction which breaks the tests
    address public constant USDC = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;
    address public constant USDT = 0xB75D0B03c06A926e488e2659DF1A861F860bD3d1;
    address payable public constant WSEI = payable(0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7);
    string public constant URL = "https://evm-rpc.sei-apis.com";

    function setUp() public {
        vm.createSelectFork(URL);
        competition =
            new Competition();

        competition.initialize(block.timestamp, block.timestamp + 1 days, address(DS_ROUTER), USDC, USDT, swapTokens);

        (bool success,) = WSEI.call{value: 100e18}("");

        address[] memory wseiUsdcPath = new address[](2);
        wseiUsdcPath[0] = WSEI;
        wseiUsdcPath[1] = USDC;

        address[] memory wseiUsdtPath = new address[](2);
        wseiUsdtPath[0] = WSEI;
        wseiUsdtPath[1] = USDT;

        IERC20(WSEI).approve(address(DS_ROUTER), 100e18);
        DS_ROUTER.swapExactTokensForTokens(50e18, 0, wseiUsdcPath, address(this));
        DS_ROUTER.swapExactTokensForTokens(50e18, 0, wseiUsdtPath, address(this));

        console.log(IERC20(USDC).balanceOf(address(this)));
        console.log(IERC20(USDT).balanceOf(address(this)));
    }

    function test_depositViaFunction() public {
        vm.skip(true);
        // assertEq(IWSEI(WSEI).balanceOf(address(competition)), 0);
        // uint256 depositAmount = 1 ether;
        // competition.deposit{value: depositAmount}();
        // assertEq(IWSEI(WSEI).balanceOf(address(competition)), depositAmount);
    }

    function test_depositDirectly() public {
        vm.skip(true);
        // assertEq(IWSEI(WSEI).balanceOf(address(competition)), 0);
        // uint256 depositAmount = 1 ether;
        // (bool success, ) = payable(competition).call{value: depositAmount}("");
        // assert(success);
        // assertEq(IWSEI(WSEI).balanceOf(address(competition)), depositAmount);
    }

    function test_AddNewSwapToken() public {
        assertEq(competition.isSwapToken(WSEI), false);
        swapTokens.push(WSEI);
        competition.addSwapTokens(swapTokens);
        assertEq(competition.isSwapToken(WSEI), true);
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
