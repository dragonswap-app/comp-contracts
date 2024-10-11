// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Factory} from "../src/Factory.sol";
import {Competition} from "../src/Competition.sol";

/// @notice This script adds swap tokens to an existing Competition contract.
/// 
/// To use this script:
/// 1. Ensure you have a `.env` file with your `PRIVATE_KEY` set.
/// 2. Ensure you have a `config.json` file with the following fields:
///    {
///      "competitionAddress": "0x...",
///      "swapTokens": ["0x...", "0x..."],
///      "NETWORK": "mainnet" or "testnet",
///      "TESTNET_RPC_URL": "https://...",
///      "MAINNET_RPC_URL": "https://..."
///    }
/// 3. Run the script using Forge:
///    `forge script script/AddSwapTokens.s.sol:AddSwapTokensScript --broadcast --rpc-url <RPC_URL>`
///    Replace <RPC_URL> with the appropriate RPC URL for your chosen network.
/// 
/// The script will:
/// - Connect to the specified network
/// - Add the swap tokens listed in the config to the Competition contract
/// - Log the results of the operation
///
/// After running, check the console output for confirmation of successful token addition.


contract AddSwapTokensScript is Script {
    struct Config {
        address competitionAddress;
        address[] swapTokens;
        string network;
        string testnetRpcUrl;
        string mainnetRpcUrl;
    }

    function setUp() public {}

    function run() public {
        Config memory config = readConfig();
        
        string memory rpcUrl;
        if (keccak256(abi.encodePacked(config.network)) == keccak256(abi.encodePacked("mainnet"))) {
            rpcUrl = config.mainnetRpcUrl;
        } else if (keccak256(abi.encodePacked(config.network)) == keccak256(abi.encodePacked("testnet"))) {
            rpcUrl = config.testnetRpcUrl;
        } else {
            revert(string(abi.encodePacked("Invalid network specified: ", config.network)));
        }

        vm.createSelectFork(rpcUrl);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Adding swap tokens to Competition on", config.network);
        console.log("Competition address:", config.competitionAddress);
        console.log("Number of tokens to add:", config.swapTokens.length);

        Competition competition = Competition(config.competitionAddress);
        competition.addSwapTokens(config.swapTokens);

        console.log("Swap tokens added successfully");

        vm.stopBroadcast();
    }

    function readConfig() internal view returns (Config memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/config.json");
        string memory jsonConfig = vm.readFile(configPath);
        
        bytes memory competitionAddressBytes = vm.parseJson(jsonConfig, ".competitionAddress");
        bytes memory swapTokensBytes = vm.parseJson(jsonConfig, ".swapTokens");
        bytes memory networkBytes = vm.parseJson(jsonConfig, ".NETWORK");
        bytes memory testnetRpcUrlBytes = vm.parseJson(jsonConfig, ".TESTNET_RPC_URL");
        bytes memory mainnetRpcUrlBytes = vm.parseJson(jsonConfig, ".MAINNET_RPC_URL");

        address[] memory swapTokens = abi.decode(swapTokensBytes, (address[]));

        return Config({
            competitionAddress: abi.decode(competitionAddressBytes, (address)),
            swapTokens: swapTokens,
            network: abi.decode(networkBytes, (string)),
            testnetRpcUrl: abi.decode(testnetRpcUrlBytes, (string)),
            mainnetRpcUrl: abi.decode(mainnetRpcUrlBytes, (string))
        });
    }
}