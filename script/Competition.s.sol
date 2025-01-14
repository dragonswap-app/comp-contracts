// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Factory} from "../src/Factory.sol";
import {Competition} from "../src/Competition.sol";

contract CompetitionScript is Script {
    struct Config {
        uint256 startTimestamp;
        uint256 endTimestamp;
        address router;
        address[] stableCoins;
        address[] swapTokens;
    }

    function setUp() public {}

    function run() public {
        Config memory config = readConfig();

        // Set the RPC URL
        vm.createSelectFork(vm.envString("RPC_URL"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Adjust gas price
        uint256 gasPrice = uint256(tx.gasprice);

        vm.startBroadcast(deployerPrivateKey);
        vm.txGasPrice(gasPrice * 120 / 100); // 20% higher than current gas price

        // Deploy Competition through Factory
        address factoryAddress = readFactoryAddress();
        Factory factory = Factory(factoryAddress);

        // Capture logs
        vm.recordLogs();

        factory.deploy(
            config.startTimestamp, config.endTimestamp, config.router, config.stableCoins, config.swapTokens
        );

        vm.stopBroadcast();

        // Parse logs to get the competition address
        address competitionAddress;
        bytes32 deployedEventSignature = keccak256("Deployed(address,address)");

        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == deployedEventSignature) {
                competitionAddress = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        if (competitionAddress == address(0)) {
            revert("Failed to retrieve Competition address from event");
        }

        console.log("Competition deployed at:", competitionAddress);

        writeCompetitionDeploymentAddress(competitionAddress);

        console.log("Deployment completed successfully");
    }

    function readConfig() internal view returns (Config memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/config.json");
        string memory jsonConfig = vm.readFile(configPath);

        bytes memory startTimestampBytes = vm.parseJson(jsonConfig, ".startTimestamp");
        bytes memory endTimestampBytes = vm.parseJson(jsonConfig, ".endTimestamp");
        bytes memory routerBytes = vm.parseJson(jsonConfig, ".router");
        bytes memory stableCoinsBytes = vm.parseJson(jsonConfig, ".stableCoins");
        bytes memory swapTokensBytes = vm.parseJson(jsonConfig, ".swapTokens");

        address[] memory swapTokens = abi.decode(swapTokensBytes, (address[]));

        return Config({
            startTimestamp: abi.decode(startTimestampBytes, (uint256)),
            endTimestamp: abi.decode(endTimestampBytes, (uint256)),
            router: abi.decode(routerBytes, (address)),
            stableCoins: abi.decode(stableCoinsBytes, (address[])),
            swapTokens: swapTokens
        });
    }

    function readFactoryAddress() internal view returns (address) {
        string memory deploymentFile = "deployment.json";
        string memory jsonContent = vm.readFile(deploymentFile);
        console.log("Factory address:", abi.decode(vm.parseJson(jsonContent, ".FACTORY_ADDRESS"), (address)));
        return abi.decode(vm.parseJson(jsonContent, ".FACTORY_ADDRESS"), (address));
    }

    function writeCompetitionDeploymentAddress(address competitionAddress) internal {
        string memory deploymentFile = "deployment.json";
        string memory jsonContent = vm.readFile(deploymentFile);

        // Parse existing JSON content
        bytes memory factoryAddressBytes = vm.parseJson(jsonContent, ".FACTORY_ADDRESS");
        bytes memory implementationAddressBytes = vm.parseJson(jsonContent, ".COMPETITION_IMPLEMENTATION_ADDRESS");
        bytes memory competitionAddressesBytes = vm.parseJson(jsonContent, ".COMPETITION_ADDRESSES");

        // Decode existing competition addresses
        address[] memory existingAddresses;
        if (competitionAddressesBytes.length > 0) {
            existingAddresses = abi.decode(competitionAddressesBytes, (address[]));
        }

        // Create new array with additional address
        address[] memory newAddresses = new address[](existingAddresses.length + 1);
        for (uint256 i = 0; i < existingAddresses.length; i++) {
            newAddresses[i] = existingAddresses[i];
        }
        newAddresses[existingAddresses.length] = competitionAddress;

        // Create updated JSON content
        string memory updatedJsonContent = string.concat(
            "{\n",
            '    "FACTORY_ADDRESS": "',
            vm.toString(abi.decode(factoryAddressBytes, (address))),
            '",\n',
            '    "COMPETITION_IMPLEMENTATION_ADDRESS": "',
            vm.toString(abi.decode(implementationAddressBytes, (address))),
            '",\n',
            '    "COMPETITION_ADDRESSES": ',
            addressArrayToJsonString(newAddresses),
            "\n",
            "}"
        );

        // Write updated JSON content back to the file
        vm.writeFile(deploymentFile, updatedJsonContent);

        console.log("Added new Competition address:", competitionAddress);
    }

    function addressArrayToJsonString(address[] memory addresses) internal pure returns (string memory) {
        if (addresses.length == 0) {
            return "[]";
        }

        string memory result = "[\n        ";
        for (uint256 i = 0; i < addresses.length; i++) {
            if (i > 0) {
                result = string.concat(result, ",\n        ");
            }
            result = string.concat(result, '"', vm.toString(addresses[i]), '"');
        }
        result = string.concat(result, "\n    ]");
        return result;
    }
}
