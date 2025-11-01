// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";
import {StealthAnnouncer} from "../src/StealthAnnouncer.sol";
import {GasTank} from "../src/GasTank.sol";

/// @title Deployment Script
/// @notice Deploys the three core stealth address contracts
contract DeployScript is Script {
    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts in order
        StealthRegistry registry = new StealthRegistry();
        StealthAnnouncer announcer = new StealthAnnouncer();
        GasTank gasTank = new GasTank();

        // Log deployed addresses
        console.log("StealthRegistry deployed at:", address(registry));
        console.log("StealthAnnouncer deployed at:", address(announcer));
        console.log("GasTank deployed at:", address(gasTank));

        vm.stopBroadcast();
    }
}

