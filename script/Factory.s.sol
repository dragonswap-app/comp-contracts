// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Competition} from "../src/Competition.sol";

/// @notice This script deploys the Factory and Competition contracts, and sets up the Factory.
/// 
/// To use this script:
/// 1. Ensure you have a `.env` file with your `PRIVATE_KEY` set.
/// 2. Ensure you have a `config.json` file with the following fields:
///    {
///      "owner": "0x...",
///      "network": "mainnet" or "testnet",
///      "testnetRpcUrl": "https://...",
///      "mainnetRpcUrl": "https://..."
///    }
/// 3. Run the script using Forge:
///    `forge script script/Factory.s.sol:DeployFactoryScript --broadcast`
/// 
/// The script will:
/// - Deploy the Factory contract
/// - Deploy the Competition implementation contract
/// - Set the Competition implementation in the Factory
/// - Log the addresses of the deployed contracts
///
/// After running, check the console output for the deployed contract addresses.


contract DeployFactoryScript is Script {
    struct Config {
        address owner;
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

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 gasPrice = uint256(tx.gasprice);
        vm.startBroadcast(deployerPrivateKey);
        vm.txGasPrice(gasPrice * 120 / 100); // 20% higher than current gas price

        console.log("Deploying Factory on", config.network);
        console.log("Owner:", config.owner);
        console.log("RPC URL:", rpcUrl);

        // Deploy Factory contract
        Factory factory = new Factory(config.owner);
        console.log("Factory deployed at:", address(factory));

        // Deploy Competition contract
        Competition competitionImplementation = new Competition();
        console.log("Competition implementation deployed at:", address(competitionImplementation));

        // Set Competition implementation in Factory
        factory.setImplementation(address(competitionImplementation));
        console.log("Competition implementation set in Factory");

        // Confirm that correct competition address is set on Factory
        address confirmedImplementation = factory.implementation();
        if (confirmedImplementation == address(competitionImplementation)) {
            console.log("Competition implementation address confirmed in Factory");
        } else {
            console.log("Error: Competition implementation address mismatch in Factory");
            console.log("Expected:", address(competitionImplementation));
            console.log("Actual:", confirmedImplementation);
            revert("Implementation address mismatch");
        }

        vm.stopBroadcast();

        // Save deployment addresses to file
        string memory deploymentFile = string.concat("deployment_", config.network);
        vm.writeFile(deploymentFile, string.concat("FACTORY_ADDRESS=", vm.toString(address(factory)), "\n"));
        vm.writeLine(deploymentFile, string.concat("COMPETITION_IMPLEMENTATION_ADDRESS=", vm.toString(address(competitionImplementation)), "\n"));

        console.log("Deployment completed successfully on", config.network);
    }

    function readConfig() internal view returns (Config memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/config.json");
        string memory jsonConfig = vm.readFile(configPath);
        
        bytes memory ownerBytes = vm.parseJson(jsonConfig, ".owner");
        bytes memory networkBytes = vm.parseJson(jsonConfig, ".NETWORK");
        bytes memory testnetRpcUrlBytes = vm.parseJson(jsonConfig, ".TESTNET_RPC_URL");
        bytes memory mainnetRpcUrlBytes = vm.parseJson(jsonConfig, ".MAINNET_RPC_URL");

        address[] memory swapTokens = new address[](2);
        swapTokens[0] = abi.decode(vm.parseJson(jsonConfig, ".swapTokens[0]"), (address));
        swapTokens[1] = abi.decode(vm.parseJson(jsonConfig, ".swapTokens[1]"), (address));

        return Config({
            owner: abi.decode(ownerBytes, (address)),
            network: abi.decode(networkBytes, (string)),
            testnetRpcUrl: abi.decode(testnetRpcUrlBytes, (string)),
            mainnetRpcUrl: abi.decode(mainnetRpcUrlBytes, (string))
        });
    }
}