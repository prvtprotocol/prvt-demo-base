// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";

contract StealthRegistryTest is Test {
    StealthRegistry public registry;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event KeysSet(address indexed user, bytes viewingPub, bytes spendingPub, bool isUpdate);
    event KeysCleared(address indexed user);

    function setUp() public {
        registry = new StealthRegistry();
    }

    function _makeKey(uint256 seed) internal pure returns (bytes memory) {
        bytes32 x = keccak256(abi.encodePacked(seed, "x"));
        bytes32 y = keccak256(abi.encodePacked(seed, "y"));
        return abi.encodePacked(bytes1(0x04), x, y);
    }

    function test_SetKeys() public {
        bytes memory viewing = _makeKey(1);
        bytes memory spending = _makeKey(2);

        vm.expectEmit(true, false, false, true);
        emit KeysSet(alice, viewing, spending, false);

        vm.prank(alice);
        registry.setKeys(viewing, spending);

        (bytes memory storedViewing, bytes memory storedSpending) = registry.keys(alice);
        assertEq(storedViewing, viewing);
        assertEq(storedSpending, spending);
        assertTrue(registry.hasKeys(alice));
    }

    function test_SetKeysUpdate() public {
        bytes memory firstViewing = _makeKey(1);
        bytes memory firstSpending = _makeKey(2);
        bytes memory newViewing = _makeKey(3);
        bytes memory newSpending = _makeKey(4);

        vm.prank(alice);
        registry.setKeys(firstViewing, firstSpending);

        vm.expectEmit(true, false, false, true);
        emit KeysSet(alice, newViewing, newSpending, true);

        vm.prank(alice);
        registry.setKeys(newViewing, newSpending);

        (bytes memory storedViewing, bytes memory storedSpending) = registry.keys(alice);
        assertEq(storedViewing, newViewing);
        assertEq(storedSpending, newSpending);
    }

    function test_SetKeysMultipleUsers() public {
        bytes memory aliceViewing = _makeKey(1);
        bytes memory aliceSpending = _makeKey(2);
        bytes memory bobViewing = _makeKey(3);
        bytes memory bobSpending = _makeKey(4);

        vm.prank(alice);
        registry.setKeys(aliceViewing, aliceSpending);

        vm.prank(bob);
        registry.setKeys(bobViewing, bobSpending);

        (bytes memory storedAliceViewing, bytes memory storedAliceSpending) = registry.keys(alice);
        (bytes memory storedBobViewing, bytes memory storedBobSpending) = registry.keys(bob);

        assertEq(storedAliceViewing, aliceViewing);
        assertEq(storedAliceSpending, aliceSpending);
        assertEq(storedBobViewing, bobViewing);
        assertEq(storedBobSpending, bobSpending);
    }

    function test_SetKeysInvalidLengthViewing() public {
        bytes memory invalidViewing = bytes.concat(bytes1(0x04), new bytes(32)); // only 33 bytes total
        bytes memory spending = _makeKey(2);

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.InvalidKey.selector);
        registry.setKeys(invalidViewing, spending);
    }

    function test_SetKeysInvalidLengthSpending() public {
        bytes memory viewing = _makeKey(1);
        bytes memory invalidSpending = bytes.concat(bytes1(0x04), new bytes(40));

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.InvalidKey.selector);
        registry.setKeys(viewing, invalidSpending);
    }

    function test_SetKeysInvalidPrefix() public {
        bytes memory viewing = abi.encodePacked(bytes1(0x02), bytes32(uint256(1)), bytes32(uint256(2)));
        bytes memory spending = _makeKey(3);

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.InvalidKey.selector);
        registry.setKeys(viewing, spending);
    }

    function test_SetKeysZeroMaterial() public {
        bytes memory zeroKey = bytes.concat(bytes1(0x04), new bytes(64));

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.InvalidKey.selector);
        registry.setKeys(zeroKey, _makeKey(1));

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.InvalidKey.selector);
        registry.setKeys(_makeKey(1), zeroKey);
    }

    function test_SetKeysSameKeyReuse() public {
        bytes memory viewing = _makeKey(1);

        vm.prank(alice);
        vm.expectRevert(StealthRegistry.SameKeyReuse.selector);
        registry.setKeys(viewing, viewing);
    }

    function test_ClearKeys() public {
        bytes memory viewing = _makeKey(1);
        bytes memory spending = _makeKey(2);

        vm.prank(alice);
        registry.setKeys(viewing, spending);

        vm.expectEmit(true, false, false, false);
        emit KeysCleared(alice);

        vm.prank(alice);
        registry.clearKeys();

        (bytes memory storedViewing, bytes memory storedSpending) = registry.keys(alice);
        assertEq(storedViewing.length, 0);
        assertEq(storedSpending.length, 0);
        assertFalse(registry.hasKeys(alice));
    }

    function test_ClearKeysWithoutSetting() public {
        vm.expectEmit(true, false, false, false);
        emit KeysCleared(alice);

        vm.prank(alice);
        registry.clearKeys();

        assertFalse(registry.hasKeys(alice));
    }

    function test_HasKeys() public {
        assertFalse(registry.hasKeys(alice));

        vm.prank(alice);
        registry.setKeys(_makeKey(1), _makeKey(2));

        assertTrue(registry.hasKeys(alice));

        vm.prank(alice);
        registry.clearKeys();

        assertFalse(registry.hasKeys(alice));
    }

    function test_KeysAccessControl() public {
        bytes memory aliceViewing = _makeKey(1);
        bytes memory aliceSpending = _makeKey(2);
        bytes memory bobViewing = _makeKey(3);
        bytes memory bobSpending = _makeKey(4);

        vm.prank(alice);
        registry.setKeys(aliceViewing, aliceSpending);

        vm.prank(bob);
        registry.setKeys(bobViewing, bobSpending);

        (bytes memory storedAliceViewing, bytes memory storedAliceSpending) = registry.keys(alice);
        assertEq(storedAliceViewing, aliceViewing);
        assertEq(storedAliceSpending, aliceSpending);
    }

    function test_SetKeysAfterClearAllowsReuse() public {
        bytes memory viewing = _makeKey(1);
        bytes memory spending = _makeKey(2);

        vm.prank(alice);
        registry.setKeys(viewing, spending);

        vm.prank(alice);
        registry.clearKeys();

        vm.prank(alice);
        registry.setKeys(viewing, spending);

        assertTrue(registry.hasKeys(alice));
    }

    function test_VersionConstant() public view {
        assertEq(registry.version(), "1.0.0");
    }
}
