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
    // Deployed addresses on Base Sepolia
    address constant REGISTRY = 0xA4cd92f81596F55D78227F0f57DF7D105432407F;
    address constant ANNOUNCER = 0xf1Df5d9725A54a968f65365Cc84ddE3d7773ae63;
    address constant GASTANK = 0x93335Def5273Fa05F6cbba431E1Ca1CB89b16514;

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
        announcer.announce(ephem, address(0), 0, ""); // ETH payment, 0 amount, no hint

        // 3) Deposit and withdraw small amount through GasTank to show unlinkable flow
        address payable gasTankAddr = payable(GASTANK);
        bytes memory secret = abi.encodePacked(bytes32(uint256(123)));
        bytes32 h = keccak256(abi.encodePacked(secret, sender));
        GasTank(gasTankAddr).deposit{value: 1000000000000000}(h); // 0.001 ETH
        GasTank(gasTankAddr).withdraw(secret);

        vm.stopBroadcast();
    }
}

