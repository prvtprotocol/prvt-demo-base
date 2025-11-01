// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";
import {StealthAnnouncer} from "../src/StealthAnnouncer.sol";
import {GasTank} from "../src/GasTank.sol";

/// @title Demo Script - One-Click Demonstration
/// @notice Executes a minimal stealth address flow for demonstration
/// @dev Update REGISTRY, ANNOUNCER, GASTANK addresses after deployment
contract Demo is Script {
    // Fill after deploy or load from env/JSON if you prefer
    address constant REGISTRY = 0x0000000000000000000000000000000000000000;
    address constant ANNOUNCER = 0x0000000000000000000000000000000000000000;
    address constant GASTANK = 0x0000000000000000000000000000000000000000;

    // Helper to generate 65-byte uncompressed public key (0x04 + 32 bytes X + 32 bytes Y)
    function _makeKey(uint256 seed) internal pure returns (bytes memory) {
        bytes32 x = keccak256(abi.encodePacked(seed, "x"));
        bytes32 y = keccak256(abi.encodePacked(seed, "y"));
        return abi.encodePacked(bytes1(0x04), x, y);
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address sender = vm.addr(deployerPrivateKey);

        // 1) Register your wallet as a receiver (simple demo action)
        StealthRegistry registry = StealthRegistry(REGISTRY);
        bytes memory viewingKey = _makeKey(1);
        bytes memory spendingKey = _makeKey(2);
        registry.setKeys(viewingKey, spendingKey);

        // 2) Announce an ephemeral pubkey (65 bytes uncompressed secp256k1)
        StealthAnnouncer announcer = StealthAnnouncer(ANNOUNCER);
        bytes memory ephem = _makeKey(3);
        announcer.announce(ephem, 0); // fee=0 for demo

        // 3) Deposit and withdraw small amount through GasTank to show unlinkable flow
        GasTank gasTank = GasTank(GASTANK);
        bytes32 secret = bytes32(uint256(123));
        bytes32 h = keccak256(abi.encodePacked(secret, sender));
        gasTank.deposit{value: 1000000000000000}(h); // 0.001 ETH
        gasTank.withdraw(secret, sender);

        vm.stopBroadcast();
    }
}

