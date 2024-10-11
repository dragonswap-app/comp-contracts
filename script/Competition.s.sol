// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Factory} from "../src/Factory.sol";
import {Competition} from "../src/Competition.sol";

/// @notice This script deploys a new Competition contract using the Factory.
/// 
/// To use this script:
/// 1. Ensure you have a `.env` file with your `PRIVATE_KEY` set.
/// 2. Ensure you have a `config.json` file with the following fields:
///    {
///      "factoryAddress": "0x...",
///      "startTimestamp": 1234567890,
///      "endTimestamp": 1234567890,
///      "router": "0x...",
///      "stable0": "0x...",
///      "stable1": "0x...",
///      "swapTokens": ["0x...", "0x..."],
///      "network": "mainnet" or "testnet",
///      "testnetRpcUrl": "https://...",
///      "mainnetRpcUrl": "https://..."
///    }
/// 3. Run the script using Forge:
///    `forge script script/Competition.s.sol:DeployCompetitionScript --broadcast`
/// 
/// The script will:
/// - Connect to the specified network (mainnet or testnet)
/// - Use the Factory contract to deploy a new Competition contract
/// - Set up the Competition with the provided parameters
/// - Log the address of the newly deployed Competition contract
///
/// After running, check the console output for the deployed Competition contract address.


contract DeployCompetitionScript is Script {
    struct Config {
        address factoryAddress;
        uint256 startTimestamp;
        uint256 endTimestamp;
        address router;
        address stable0;
        address stable1;
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

        console.log("Deploying on network:", config.network);
        console.log("Using RPC URL:", rpcUrl);

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Adjust gas price
        uint256 gasPrice = uint256(tx.gasprice);
        uint256 adjustedGasPrice = (gasPrice * 120) / 100; // Increase by 20%

        vm.startBroadcast(deployerPrivateKey);
        vm.txGasPrice(adjustedGasPrice);

        // Deploy Competition through Factory
        Factory factory = Factory(config.factoryAddress);
        // Capture logs
        vm.recordLogs();
        
        factory.deploy(
            config.startTimestamp,
            config.endTimestamp,
            config.router,
            config.stable0,
            config.stable1,
            config.swapTokens
        );

        vm.stopBroadcast();

        // Parse logs to get the competition address
        address competitionAddress;
        address implementationAddress;
        bytes32 deployedEventSignature = keccak256("Deployed(address,address)");
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == deployedEventSignature) {
                competitionAddress = address(uint160(uint256(logs[i].topics[1])));
                implementationAddress = address(uint160(uint256(logs[i].topics[2])));
                break;
            }
        }

        if (competitionAddress == address(0)) {
            revert("Failed to retrieve Competition address from event");
        }

        console.log("Competition deployed at:", competitionAddress);

        // Save Competition address to deployment file
        string memory deploymentFile = string.concat("deployment_", config.network);
        vm.writeLine(deploymentFile, string.concat("COMPETITION_ADDRESS=", vm.toString(competitionAddress), "\n"));

        console.log("Deployment completed successfully on", config.network);
    }

    function readConfig() internal view returns (Config memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/config.json");
        string memory jsonConfig = vm.readFile(configPath);
        
        bytes memory factoryAddressBytes = vm.parseJson(jsonConfig, ".factoryAddress");
        bytes memory startTimestampBytes = vm.parseJson(jsonConfig, ".startTimestamp");
        bytes memory endTimestampBytes = vm.parseJson(jsonConfig, ".endTimestamp");
        bytes memory routerBytes = vm.parseJson(jsonConfig, ".router");
        bytes memory stable0Bytes = vm.parseJson(jsonConfig, ".stable0");
        bytes memory stable1Bytes = vm.parseJson(jsonConfig, ".stable1");
        bytes memory swapTokensBytes = vm.parseJson(jsonConfig, ".swapTokens");
        bytes memory networkBytes = vm.parseJson(jsonConfig, ".NETWORK");
        bytes memory testnetRpcUrlBytes = vm.parseJson(jsonConfig, ".TESTNET_RPC_URL");
        bytes memory mainnetRpcUrlBytes = vm.parseJson(jsonConfig, ".MAINNET_RPC_URL");

        address[] memory swapTokens = abi.decode(swapTokensBytes, (address[]));

        return Config({
            factoryAddress: abi.decode(factoryAddressBytes, (address)),
            startTimestamp: abi.decode(startTimestampBytes, (uint256)),
            endTimestamp: abi.decode(endTimestampBytes, (uint256)),
            router: abi.decode(routerBytes, (address)),
            stable0: abi.decode(stable0Bytes, (address)),
            stable1: abi.decode(stable1Bytes, (address)),
            swapTokens: swapTokens,
            network: abi.decode(networkBytes, (string)),
            testnetRpcUrl: abi.decode(testnetRpcUrlBytes, (string)),
            mainnetRpcUrl: abi.decode(mainnetRpcUrlBytes, (string))
        });
    }
}