// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Competition} from "../src/Competition.sol";


contract FactoryScript is Script {

    function setUp() public {}

    function run() public {
        // Set the RPC URL
        vm.createSelectFork(vm.envString("RPC_URL"));

        uint256 gasPrice = uint256(tx.gasprice);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address walletAddress = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        vm.txGasPrice(gasPrice * 120 / 100); // 20% higher than current gas price

        // Deploy Factory contract
        Factory factory = new Factory(walletAddress);
        console.log("Factory deployed at:", address(factory));

        // Deploy Competition contract
        Competition competitionImplementation = new Competition();
        console.log("Competition implementation deployed at:", address(competitionImplementation));

        // Set Competition implementation in Factory
        factory.setImplementation(address(competitionImplementation));
        console.log("Competition implementation set in Factory");

        vm.stopBroadcast();

        // Save deployment addresses to JSON file
        string memory jsonContent = string.concat(
            '{\n',
            '    "FACTORY_ADDRESS": "', vm.toString(address(factory)), '",\n',
            '    "COMPETITION_IMPLEMENTATION_ADDRESS": "', vm.toString(address(competitionImplementation)), '"\n',
            '}'
        );
        string memory deploymentFile = "deployment.json";
        vm.writeFile(deploymentFile, jsonContent);

        console.log("Deployment completed successfully");
    }
}