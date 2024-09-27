// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Competition} from "../src/Competition.sol";
import {Utils} from "../src/libraries/Utils.sol";
import {ISwapRouter02Minimal, IV2SwapRouter} from "../src/interfaces/ISwapRouter02Minimal.sol";
import {ICompetition} from "../src/interfaces/ICompetition.sol";
import {Factory} from "../src/Factory.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";

contract CompetitionTest is Test {
    using SafeERC20 for IERC20;

    Competition public competition;
    Factory public factory;
    address[] public swapTokens;

    ISwapRouter02Minimal public constant DS_ROUTER = ISwapRouter02Minimal(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    // @dev USDC and USDT are both native sei tokens which means they include precompile interaction which breaks the tests
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant ERC20 = 0xA700b4eB416Be35b2911fd5Dee80678ff64fF6C9;
    address payable public constant WSEI = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    string public constant URL = "wss://ethereum-rpc.publicnode.com";

    function setUp() public {
        vm.createSelectFork(URL);

        factory = new Factory(address(this));
        competition = new Competition();

        factory.setImplementation(address(competition));

        vm.recordLogs();
        factory.deploy(block.timestamp, block.timestamp + 1 days, address(DS_ROUTER), USDC, USDT, swapTokens);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("Deployed(address,address)")) {
                competition = Competition(address(uint160(uint256(entries[i].topics[1]))));
                break;
            }
        }

        (bool success,) = WSEI.call{value: 100e18}("");
        require(success, "Deposit failed");

        address[] memory wseiUsdcPath = new address[](2);
        wseiUsdcPath[0] = WSEI;
        wseiUsdcPath[1] = USDC;

        address[] memory wseiUsdtPath = new address[](2);
        wseiUsdtPath[0] = WSEI;
        wseiUsdtPath[1] = USDT;

        IERC20(WSEI).approve(address(DS_ROUTER), 100e18);
        DS_ROUTER.swapExactTokensForTokens(50e18, 0, wseiUsdcPath, address(this));
        DS_ROUTER.swapExactTokensForTokens(50e18, 0, wseiUsdtPath, address(this));
    }

    function test_addNewSwapToken() public {
        assertEq(competition.isSwapToken(ERC20), false);
        swapTokens.push(ERC20);
        competition.addSwapTokens(swapTokens);
        assertEq(competition.isSwapToken(ERC20), true);
        swapTokens.pop();
    }

    function test_addNonContractToken() public {
        swapTokens.push(address(1));
        vm.expectRevert(Utils.NotAContract.selector);
        competition.addSwapTokens(swapTokens);
        swapTokens.pop();
    }

    function test_depositUSDC() public {
        assertEq(IERC20(USDC).balanceOf(address(competition)), 0);
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);
        assertEq(IERC20(USDC).balanceOf(address(competition)), usdcDepositAmount);
    }

    function test_depositUSDT() public {
        assertEq(IERC20(USDT).balanceOf(address(competition)), 0);
        uint256 usdtDepositAmount = 10000000; // 10 USDT (6 decimals)
        IERC20(USDT).safeIncreaseAllowance(address(competition), usdtDepositAmount);
        competition.deposit(false, usdtDepositAmount);
        assertEq(IERC20(USDT).balanceOf(address(competition)), usdtDepositAmount);
    }

    function test_depositInsufficientAmount() public {
        assertEq(IERC20(USDC).balanceOf(address(competition)), 0);
        uint256 usdcDepositAmount = 9000000; // 9 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        vm.expectRevert(ICompetition.InsufficientAmount.selector);
        competition.deposit(true, usdcDepositAmount);
    }

    function test_exit() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Verify WSEI is now a valid swap token
        assertTrue(competition.isSwapToken(WSEI), "WSEI should be a valid swap token");

        // Deposit USDT
        assertEq(IERC20(USDT).balanceOf(address(competition)), 0);
        uint256 usdtDepositAmount = 10000000; // 10 USDT (6 decimals)
        IERC20(USDT).safeIncreaseAllowance(address(competition), usdtDepositAmount);
        competition.deposit(false, usdtDepositAmount);

        // Swap USDT to WSEI
        address[] memory usdtWseiPath = new address[](2);
        usdtWseiPath[0] = USDT;
        usdtWseiPath[1] = WSEI;

        // Check if the swap path is valid
        require(competition.isSwapToken(USDT), "USDT is not a valid swap token");
        require(competition.isSwapToken(WSEI), "WSEI is not a valid swap token");

        // Perform the swap
        uint256 amountOut =
            competition.swapExactTokensForTokens(usdtDepositAmount, 0, usdtWseiPath, address(competition));

        // Check that the swap was successful
        assertGt(amountOut, 0, "Swap should return a non-zero amount");

        // Exit
        competition.exit();

        // Check that the user's USDT and WSEI balances are 0
        assertEq(IERC20(USDT).balanceOf(address(competition)), 0);
        assertEq(IERC20(WSEI).balanceOf(address(competition)), 0);
    }

    function test_swapExactTokensForTokens() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Verify WSEI is now a valid swap token
        assertTrue(competition.isSwapToken(WSEI), "WSEI should be a valid swap token");

        // Deposit USDT
        assertEq(IERC20(USDT).balanceOf(address(competition)), 0);
        uint256 usdtDepositAmount = 10000000; // 10 USDT (6 decimals)
        IERC20(USDT).safeIncreaseAllowance(address(competition), usdtDepositAmount);
        competition.deposit(false, usdtDepositAmount);

        // Swap USDT to WSEI
        address[] memory usdtWseiPath = new address[](2);
        usdtWseiPath[0] = USDT;
        usdtWseiPath[1] = WSEI;

        // Perform the swap
        uint256 amountOut =
            competition.swapExactTokensForTokens(usdtDepositAmount, 0, usdtWseiPath, address(competition));

        // Check that the swap was successful
        assertGt(amountOut, 0, "Amount out should be greater than zero");
        assertEq(competition.balances(address(this), WSEI), amountOut, "WSEI balance should match amount out");
        assertEq(competition.balances(address(this), USDT), 0, "USDT balance should be zero after swap");
    }

    function test_swapExactTokensForTokensFailDueToInvalidRoute() public {
        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 1000000000000; // 0.000001 WSEI (18 decimals)
        uint256 amountInMax = 1000000; // 1 USDC (6 decimals)
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WSEI;

        // Perform the swap
        vm.expectRevert(ICompetition.InvalidRoute.selector);
        competition.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
    }

    function test_swapExactTokensForTokensFailDueToInsufficientBalance() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 10000000000; // 0.0001 WSEI (18 decimals)
        uint256 amountInMax = 100000000; // 100 USDC (6 decimals)
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WSEI;

        // Perform the swap
        vm.expectRevert(ICompetition.InsufficientBalance.selector);
        competition.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
    }

    function test_swapTokensForExactTokens() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 1000000000000; // 0.000001 WSEI (18 decimals)
        uint256 amountInMax = 1000000; // 1 USDC (6 decimals)
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WSEI;

        // Perform the swap
        uint256 amountIn = competition.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));

        // Check that the swap was successful
        assertLe(amountIn, amountInMax, "Amount in should be less than or equal to max amount");
        assertEq(competition.balances(address(this), WSEI), amountOut, "WSEI balance should match amount out");
        assertEq(
            competition.balances(address(this), USDC),
            usdcDepositAmount - amountIn,
            "USDC balance should be reduced by amount in"
        );
    }

    function test_swapTokensForExactTokensFailDueToInvalidRoute() public {
        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 1000000000000; // 0.000001 WSEI (18 decimals)
        uint256 amountInMax = 1000000; // 1 USDC (6 decimals)
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WSEI;

        // Perform the swap
        vm.expectRevert(ICompetition.InvalidRoute.selector);
        competition.swapTokensForExactTokens(amountOut, amountInMax, path, address(this));
    }

    function test_swapTokensForExactTokensFailDueToInsufficientBalance() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 10000000000; // 0.0001 WSEI (18 decimals)
        uint256 amountInMax = 100000000; // 100 USDC (6 decimals)
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WSEI;

        // Perform the swap
        vm.expectRevert(ICompetition.InsufficientBalance.selector);
        competition.swapExactTokensForTokens(amountOut, amountInMax, path, address(this));
    }

    function test_ExactInputSingle() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountIn = 1000000; // 1 USDC (6 decimals)
        uint256 amountOutMinimum = 1; // Minimum amount of WSEI to receive
        IV2SwapRouter.ExactInputSingleParams memory params = IV2SwapRouter.ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: WSEI,
            fee: 3000, // 0.3% fee tier
            recipient: address(competition),
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // Perform the swap
        uint256 amountOut = competition.exactInputSingle(params);

        // Check that the swap was successful
        assertGt(amountOut, 0, "Amount out should be greater than zero");
        assertGe(amountOut, amountOutMinimum, "Amount out should be greater than or equal to minimum amount");
        assertEq(competition.balances(address(this), WSEI), amountOut, "WSEI balance should match amount out");
        assertEq(
            competition.balances(address(this), USDC),
            usdcDepositAmount - amountIn,
            "USDC balance should be reduced by amount in"
        );
    }

    function test_ExactInputSingleFailDueToInvalidRoute() public {
        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an invalid route (WSEI is not added as a swap token)
        IV2SwapRouter.ExactInputSingleParams memory params = IV2SwapRouter.ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: WSEI,
            fee: 3000,
            recipient: address(competition),
            amountIn: 1000000, // 1 USDC
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        // Expect the swap to revert due to InvalidRoute
        vm.expectRevert(ICompetition.InvalidRoute.selector);
        competition.exactInputSingle(params);
    }

    function test_ExactInputSingleFailDueToInsufficientBalance() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit a small amount of USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an amount greater than the deposited balance
        IV2SwapRouter.ExactInputSingleParams memory params = IV2SwapRouter.ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: WSEI,
            fee: 3000,
            recipient: address(competition),
            amountIn: 100000000, // 100 USDC (more than deposited)
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        // Expect the swap to revert due to InsufficientBalance
        vm.expectRevert(ICompetition.InsufficientBalance.selector);
        competition.exactInputSingle(params);
    }

    function test_ExactInput() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountIn = 1000000; // 1 USDC (6 decimals)
        uint256 amountOutMinimum = 1; // Minimum amount of WSEI to receive

        // Perform the swap
        IV2SwapRouter.ExactInputParams memory params = IV2SwapRouter.ExactInputParams({
            path: abi.encodePacked(USDC, uint24(3000), WSEI),
            recipient: address(competition),
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });
        uint256 amountOut = competition.exactInput(params);

        // Check that the swap was successful
        assertGt(amountOut, 0, "Amount out should be greater than zero");
        assertGe(amountOut, amountOutMinimum, "Amount out should be greater than or equal to minimum amount");
        assertEq(competition.balances(address(this), WSEI), amountOut, "WSEI balance should match amount out");
        assertEq(
            competition.balances(address(this), USDC),
            usdcDepositAmount - amountIn,
            "USDC balance should be reduced by amount in"
        );
    }

    function test_ExactInputFailDueToInvalidRoute() public {
        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an invalid route (USDC to WSEI, where WSEI is not a swap token)
        IV2SwapRouter.ExactInputParams memory params = IV2SwapRouter.ExactInputParams({
            path: abi.encodePacked(USDC, uint24(3000), WSEI),
            recipient: address(competition),
            amountIn: 1000000, // 1 USDC
            amountOutMinimum: 1
        });

        // Expect the swap to revert due to InvalidRoute
        vm.expectRevert(ICompetition.InvalidRoute.selector);
        competition.exactInput(params);
    }

    function test_ExactInputFailDueToInsufficientBalance() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an amount greater than the deposited balance
        IV2SwapRouter.ExactInputParams memory params = IV2SwapRouter.ExactInputParams({
            path: abi.encodePacked(USDC, uint24(3000), WSEI),
            recipient: address(competition),
            amountIn: 20000000, // 20 USDC (more than deposited)
            amountOutMinimum: 1
        });

        // Expect the swap to revert due to InsufficientBalance
        vm.expectRevert(ICompetition.InsufficientBalance.selector);
        competition.exactInput(params);
    }

    function test_ExactOutputSingle() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters
        uint256 amountOut = 1e15; // 0.001 WSEI (18 decimals)
        uint256 amountInMaximum = 5000000; // Increased to 5 USDC (6 decimals)

        IV2SwapRouter.ExactOutputSingleParams memory params = IV2SwapRouter.ExactOutputSingleParams({
            tokenIn: USDC,
            tokenOut: WSEI,
            fee: 3000, // 0.3% fee tier
            recipient: address(competition),
            amountOut: amountOut,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        // Perform the swap
        uint256 amountIn = competition.exactOutputSingle(params);

        // Check that the swap was successful
        assertGt(amountIn, 0, "Amount in should be greater than zero");
        assertLe(amountIn, amountInMaximum, "Amount in should be less than or equal to maximum amount");
        assertEq(competition.balances(address(this), WSEI), amountOut, "WSEI balance should match amount out");
        assertEq(
            competition.balances(address(this), USDC),
            usdcDepositAmount - amountIn,
            "USDC balance should be reduced by amount in"
        );
    }

    function test_ExactOutput1() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit USDC
        uint256 usdcDepositAmount = 100000000; // 100 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up ExactOutput swap parameters for USDC to WSEI
        uint256 amountOut = 1e14; // 0.0001 WSEI (18 decimals)
        uint256 amountInMaximum = 10000000; // 10 USDC (6 decimals)

        IV2SwapRouter.ExactOutputParams memory exactOutputParams = IV2SwapRouter.ExactOutputParams({
            path: abi.encodePacked(WSEI, uint24(3000), USDC), // Corrected path order
            recipient: address(competition),
            amountOut: amountOut,
            amountInMaximum: amountInMaximum
        });

        console.log("usdc balance", IERC20(USDC).balanceOf(address(competition)));
        console.log("wsei balance", IERC20(WSEI).balanceOf(address(competition)));

        // Perform the ExactOutput swap
        uint256 amountIn = competition.exactOutput(exactOutputParams);

        console.log("amountIn", amountIn);
        console.log("usdc balance", IERC20(USDC).balanceOf(address(competition)));
        console.log("wsei balance", IERC20(WSEI).balanceOf(address(competition)));
        console.log("usdc user balance on competition", competition.balances(address(this), USDC));
        console.log("wsei user balance on competition", competition.balances(address(this), WSEI));

        // Check that the ExactOutput swap was successful
        assertGt(amountIn, 0, "ExactOutput: Amount in should be greater than zero");
        assertLe(amountIn, amountInMaximum, "ExactOutput: Amount in should be less than or equal to maximum amount");
        assertEq(
            competition.balances(address(this), WSEI), amountOut, "ExactOutput: WSEI balance should match amount out"
        );
        assertEq(
            competition.balances(address(this), USDC),
            usdcDepositAmount - amountIn,
            "ExactOutput: USDC balance should be reduced by amount in"
        );
    }

    function test_ExactOutputFailDueToInvalidRoute() public {
        // Deposit USDC
        uint256 usdcDepositAmount = 10000000; // 10 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an invalid route (USDC to WSEI, where WSEI is not a swap token)
        uint256 amountOut = 1e18; // 1 WSEI (18 decimals)
        uint256 amountInMaximum = 5000000; // 5 USDC (6 decimals)

        IV2SwapRouter.ExactOutputParams memory params = IV2SwapRouter.ExactOutputParams({
            path: abi.encodePacked(WSEI, uint24(3000), USDC), // Invalid route: WSEI is not a swap token
            recipient: address(competition),
            amountOut: amountOut,
            amountInMaximum: amountInMaximum
        });

        // Expect the transaction to revert with InvalidRoute error
        vm.expectRevert(ICompetition.InvalidRoute.selector);
        competition.exactOutput(params);
    }

    function test_ExactOutputFailDueToInsufficientBalance() public {
        // Add WSEI as a swap token
        address[] memory newSwapTokens = new address[](1);
        newSwapTokens[0] = WSEI;
        competition.addSwapTokens(newSwapTokens);

        // Deposit a small amount of USDC
        uint256 usdcDepositAmount = 10000000; // 1 USDC (6 decimals)
        IERC20(USDC).approve(address(competition), usdcDepositAmount);
        competition.deposit(true, usdcDepositAmount);

        // Set up swap parameters with an amount larger than the deposited balance
        uint256 amountOut = 1e16; // 0.01 WSEI (18 decimals)
        uint256 amountInMaximum = 20000000; // 20 USDC (6 decimals), which is more than deposited

        IV2SwapRouter.ExactOutputParams memory params = IV2SwapRouter.ExactOutputParams({
            path: abi.encodePacked(WSEI, uint24(3000), USDC),
            recipient: address(competition),
            amountOut: amountOut,
            amountInMaximum: amountInMaximum
        });

        // Expect the transaction to revert with InsufficientBalance error
        vm.expectRevert(ICompetition.InsufficientBalance.selector);
        competition.exactOutput(params);
    }
}
