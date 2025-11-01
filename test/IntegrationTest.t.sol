// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";
import {StealthAnnouncer} from "../src/StealthAnnouncer.sol";
import {GasTank} from "../src/GasTank.sol";
import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";

contract IntegrationTest is Test {
    StealthRegistry internal registry;
    StealthAnnouncer internal announcer;
    GasTank internal gasTank;
    MockERC20Permit internal feeToken;

    address internal owner = makeAddr("owner");
    address internal sender = makeAddr("sender");
    address internal receiver = makeAddr("receiver");
    address internal relayer = makeAddr("relayer");
    address internal feeRecipient = makeAddr("feeRecipient");

    bytes internal constant SECRET = "integration_secret_1234567890abcdef";

    event StealthPayment(bytes ephemeralPubkey, address indexed token, uint256 amount, bytes hint);

    function setUp() public {
        registry = new StealthRegistry();
        vm.prank(owner);
        announcer = new StealthAnnouncer();
        gasTank = new GasTank();

        feeToken = new MockERC20Permit("PRVT", "PRVT", 1_000_000 ether);
        feeToken.mint(sender, 10_000 ether);
        feeToken.mint(relayer, 10_000 ether);

        vm.label(owner, "Owner");
        vm.label(sender, "Sender");
        vm.label(receiver, "Receiver");
        vm.label(relayer, "Relayer");
        vm.label(address(registry), "StealthRegistry");
        vm.label(address(announcer), "StealthAnnouncer");
        vm.label(address(gasTank), "GasTank");
    }

    function _makeKey(uint256 seed) internal pure returns (bytes memory) {
        bytes32 x = keccak256(abi.encodePacked(seed, "x"));
        bytes32 y = keccak256(abi.encodePacked(seed, "y"));
        return abi.encodePacked(bytes1(0x04), x, y);
    }

    function _makeEphemeralKey(uint256 seed) internal pure returns (bytes memory) {
        return _makeKey(1_000 + seed);
    }

    function test_CompleteStealthFlow() public {
        // Receiver registers viewing/spending keys
        bytes memory viewingKey = _makeKey(1);
        bytes memory spendingKey = _makeKey(2);

        vm.prank(receiver);
        registry.setKeys(viewingKey, spendingKey);

        assertTrue(registry.hasKeys(receiver));

        // Initialize announcement fees
        uint256 announceFee = 0.25 ether;
        vm.prank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, announceFee);

        // Sender approves fee payment
        vm.prank(sender);
        feeToken.approve(address(announcer), announceFee);

        // Relayer funds gas for receiver via hash commitment
        bytes32 gasHash = keccak256(abi.encodePacked(SECRET, receiver));
        vm.deal(relayer, 10 ether);

        vm.prank(relayer);
        gasTank.deposit{value: 1 ether}(gasHash);

        // Sender emits stealth announcement
        bytes memory ephemeralKey = _makeEphemeralKey(1);
        vm.prank(sender);
        announcer.announce(ephemeralKey, address(feeToken), 123 ether, "0xdeadbeef");

        // Receiver withdraws committed gas
        uint256 receiverBalanceBefore = receiver.balance;
        vm.prank(receiver);
        gasTank.withdraw(SECRET);

        assertEq(receiver.balance, receiverBalanceBefore + 1 ether);
        assertEq(gasTank.balanceOf(gasHash), 0);
        assertEq(feeToken.balanceOf(feeRecipient), announceFee);
    }

    function test_KeyRotationFlow() public {
        bytes memory firstViewing = _makeKey(3);
        bytes memory firstSpending = _makeKey(4);
        bytes memory newViewing = _makeKey(5);
        bytes memory newSpending = _makeKey(6);

        vm.prank(receiver);
        registry.setKeys(firstViewing, firstSpending);
        assertTrue(registry.hasKeys(receiver));

        vm.prank(receiver);
        registry.clearKeys();
        assertFalse(registry.hasKeys(receiver));

        vm.prank(receiver);
        registry.setKeys(newViewing, newSpending);

        (bytes memory viewingStored, bytes memory spendingStored) = registry.keys(receiver);
        assertEq(viewingStored, newViewing);
        assertEq(spendingStored, newSpending);
    }

    function test_BatchWithdrawMultipleCommitments() public {
        vm.deal(relayer, 10 ether);

        bytes32 hash1 = keccak256(abi.encodePacked(bytes("secret-1"), receiver));
        bytes32 hash2 = keccak256(abi.encodePacked(bytes("secret-2"), receiver));
        bytes32 hash3 = keccak256(abi.encodePacked(bytes("secret-3"), receiver));

        vm.startPrank(relayer);
        gasTank.deposit{value: 0.4 ether}(hash1);
        gasTank.deposit{value: 0.5 ether}(hash2);
        gasTank.deposit{value: 0.6 ether}(hash3);
        vm.stopPrank();

        bytes[] memory secrets = new bytes[](3);
        secrets[0] = bytes("secret-1");
        secrets[1] = bytes("secret-2");
        secrets[2] = bytes("secret-3");

        uint256 receiverBalanceBefore = receiver.balance;
        vm.prank(receiver);
        gasTank.batchWithdraw(secrets);

        assertEq(receiver.balance, receiverBalanceBefore + 1.5 ether);
        assertEq(gasTank.balanceOf(hash1), 0);
        assertEq(gasTank.balanceOf(hash2), 0);
        assertEq(gasTank.balanceOf(hash3), 0);
    }
}
