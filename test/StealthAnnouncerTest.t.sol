// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StealthAnnouncer} from "../src/StealthAnnouncer.sol";
import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";

contract StealthAnnouncerTest is Test {
    StealthAnnouncer public announcer;
    MockERC20Permit public feeToken;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public feeRecipient = makeAddr("feeRecipient");
    address public exemptUser = makeAddr("exemptUser");

    bytes internal validEphemeralKey;

    event StealthPayment(bytes ephemeralPubkey, address indexed token, uint256 amount, bytes hint);
    event FeeCollected(address indexed payer, uint256 amount);
    event FeeChanged(uint256 oldFee, uint256 newFee);
    event FeeChangeProposed(uint256 newFee, uint256 executeAfter);
    event FeeChangeCancelled(uint256 cancelledFee, uint256 cancelledTimestamp);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FeeExemptionSet(address indexed account, bool exempt);
    event FeesPaused(address indexed by, uint256 until);
    event FeesUnpaused(address indexed by);
    event FeeTokenSet(address indexed feeToken);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        vm.prank(owner);
        announcer = new StealthAnnouncer();

        feeToken = new MockERC20Permit("PRVT", "PRVT", 1_000_000 ether);
        feeToken.mint(alice, 1000 ether);
        feeToken.mint(bob, 1000 ether);
        feeToken.mint(exemptUser, 1000 ether);

        validEphemeralKey = _makeEphemeralKey(1);
    }

    function _makeEphemeralKey(uint256 seed) internal pure returns (bytes memory) {
        bytes32 x = keccak256(abi.encodePacked(seed, "x"));
        bytes32 y = keccak256(abi.encodePacked(seed, "y"));
        return abi.encodePacked(bytes1(0x04), x, y);
    }

    // ========== Deployment Tests ==========

    function test_Deployment() public view {
        assertEq(announcer.owner(), owner);
        assertEq(announcer.announceFee(), 0);
        assertFalse(announcer.isInitialized());
        assertFalse(announcer.feesEnabled());
    }

    // ========== Announce Tests (No Fees) ==========

    function test_AnnounceNoFee() public {
        address token = address(0x1234);
        uint256 amount = 100 ether;
        bytes memory hint = "0xabcd";

        vm.expectEmit(true, true, false, true);
        emit StealthPayment(validEphemeralKey, token, amount, hint);

        vm.prank(alice);
        announcer.announce(validEphemeralKey, token, amount, hint);
    }

    function test_AnnounceMultipleTimes() public {
        address token = address(0x1234);
        uint256 amount = 100 ether;

        vm.startPrank(alice);
        announcer.announce(validEphemeralKey, token, amount, "0x1111");
        announcer.announce(validEphemeralKey, token, amount, "0x2222");
        announcer.announce(validEphemeralKey, token, amount, "0x3333");
        vm.stopPrank();
    }

    function test_AnnounceZeroAmount() public {
        address token = address(0x1234);
        vm.prank(alice);
        announcer.announce(validEphemeralKey, token, 0, "0x");
    }

    function test_AnnounceZeroAddressToken() public {
        vm.prank(alice);
        announcer.announce(validEphemeralKey, address(0), 100 ether, "0x");
    }

    function test_AnnounceInvalidKeyLength() public {
        bytes memory invalidKey64 = bytes.concat(bytes1(0x04), new bytes(63));
        bytes memory invalidKey66 = bytes.concat(bytes1(0x04), new bytes(65));

        vm.startPrank(alice);
        vm.expectRevert(StealthAnnouncer.InvalidEphemeralKey.selector);
        announcer.announce(invalidKey64, address(0x1234), 100 ether, "0x");

        vm.expectRevert(StealthAnnouncer.InvalidEphemeralKey.selector);
        announcer.announce(invalidKey66, address(0x1234), 100 ether, "0x");
        vm.stopPrank();
    }

    function test_AnnounceInvalidKeyPrefix() public {
        bytes memory invalidKey = bytes.concat(bytes1(0x03), new bytes(64)); // Wrong prefix

        vm.prank(alice);
        vm.expectRevert(StealthAnnouncer.InvalidEphemeralKey.selector);
        announcer.announce(invalidKey, address(0x1234), 100 ether, "0x");
    }

    function test_AnnounceZeroKey() public {
        bytes memory zeroKey = bytes.concat(bytes1(0x04), new bytes(64)); // All zeros after prefix

        vm.prank(alice);
        vm.expectRevert(StealthAnnouncer.InvalidEphemeralKey.selector);
        announcer.announce(zeroKey, address(0x1234), 100 ether, "0x");
    }

    // ========== Fee Initialization Tests ==========

    function test_InitializeFees() public {
        uint256 initialFee = 0.5 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit FeeTokenSet(address(feeToken));
        emit FeeRecipientChanged(address(0), feeRecipient);
        emit FeeChanged(0, initialFee);
        announcer.initializeFees(address(feeToken), feeRecipient, initialFee);
        vm.stopPrank();

        assertTrue(announcer.isInitialized());
        assertEq(address(announcer.feeToken()), address(feeToken));
        assertEq(announcer.feeRecipient(), feeRecipient);
        assertEq(announcer.announceFee(), initialFee);
        assertTrue(announcer.feesEnabled());
    }

    function test_InitializeFeesRevertOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(StealthAnnouncer.OnlyOwner.selector);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
    }

    function test_InitializeFeesRevertAlreadyInitialized() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.AlreadyInitialized.selector);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.stopPrank();
    }

    function test_InitializeFeesRevertInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert(StealthAnnouncer.InvalidFeeToken.selector);
        announcer.initializeFees(address(0), feeRecipient, 0.5 ether);
    }

    function test_InitializeFeesRevertInvalidRecipient() public {
        vm.prank(owner);
        vm.expectRevert(StealthAnnouncer.InvalidFeeRecipient.selector);
        announcer.initializeFees(address(feeToken), address(0), 0.5 ether);
    }

    function test_InitializeFeesRevertFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(StealthAnnouncer.FeeTooHigh.selector);
        announcer.initializeFees(address(feeToken), feeRecipient, 11 ether); // > 10 ether max
    }

    function test_InitializeFeesZeroFee() public {
        vm.prank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0);

        assertTrue(announcer.isInitialized());
        assertEq(announcer.announceFee(), 0);
        assertFalse(announcer.feesEnabled()); // Zero fee means fees not enabled
    }

    // ========== Announce with Fees Tests ==========

    function test_AnnounceWithFee() public {
        uint256 fee = 0.5 ether;
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        vm.stopPrank();

        uint256 feeRecipientBalanceBefore = feeToken.balanceOf(feeRecipient);
        uint256 aliceBalanceBefore = feeToken.balanceOf(alice);

        vm.prank(alice);
        feeToken.approve(address(announcer), fee);

        vm.prank(alice);
        announcer.announce(validEphemeralKey, address(0x1234), 100 ether, "0x");

        assertEq(feeToken.balanceOf(feeRecipient), feeRecipientBalanceBefore + fee);
        assertEq(feeToken.balanceOf(alice), aliceBalanceBefore - fee);
    }

    function test_AnnounceWithFeeExemptUser() public {
        uint256 fee = 0.5 ether;
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        announcer.setFeeExemption(exemptUser, true);
        vm.stopPrank();

        uint256 exemptUserBalanceBefore = feeToken.balanceOf(exemptUser);

        vm.prank(exemptUser);
        announcer.announce(validEphemeralKey, address(0x1234), 100 ether, "0x");

        assertEq(feeToken.balanceOf(exemptUser), exemptUserBalanceBefore); // No fee deducted
        assertEq(announcer.getEffectiveFee(exemptUser), 0);
    }

    function test_AnnounceWithFeePaused() public {
        uint256 fee = 0.5 ether;
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        announcer.pauseFees(30 days);
        vm.stopPrank();

        uint256 aliceBalanceBefore = feeToken.balanceOf(alice);

        vm.prank(alice);
        announcer.announce(validEphemeralKey, address(0x1234), 100 ether, "0x");

        assertEq(feeToken.balanceOf(alice), aliceBalanceBefore); // No fee deducted when paused
    }

    // ========== Announce with Permit Tests ==========

    function test_AnnounceWithPermitUsingAllowance() public {
        uint256 fee = 0.5 ether;
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        vm.stopPrank();

        // Pre-approve (simulating permit being frontrun or using allowance fallback)
        vm.prank(alice);
        feeToken.approve(address(announcer), fee);

        uint256 aliceBalanceBefore = feeToken.balanceOf(alice);

        // Use invalid permit signature - will fallback to allowance
        vm.prank(alice);
        announcer.announceWithPermit(
            validEphemeralKey,
            address(0x1234),
            100 ether,
            "0x",
            block.timestamp + 1 hours,
            0,
            bytes32(0),
            bytes32(0)
        );

        assertEq(feeToken.balanceOf(alice), aliceBalanceBefore - fee);
    }

    function test_AnnounceWithPermitRevertNoPermitNoAllowance() public {
        uint256 fee = 0.5 ether;
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        vm.stopPrank();

        // No approval set, invalid permit signature
        vm.prank(alice);
        vm.expectRevert(StealthAnnouncer.TransferFailed.selector);
        announcer.announceWithPermit(
            validEphemeralKey,
            address(0x1234),
            100 ether,
            "0x",
            block.timestamp + 1 hours,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    // ========== Fee Change Tests ==========

    function test_ProposeFeeChange() public {
        uint256 initialFee = 0.5 ether;
        uint256 newFee = 1 ether;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, initialFee);
        vm.expectEmit(true, false, false, true);
        emit FeeChangeProposed(newFee, block.timestamp + announcer.FEE_CHANGE_DELAY());
        announcer.proposeFeeChange(newFee);
        vm.stopPrank();

        assertEq(announcer.pendingFee(), newFee);
        assertEq(announcer.feeChangeTimestamp(), block.timestamp + announcer.FEE_CHANGE_DELAY());
        assertFalse(announcer.canExecuteFeeChange());
    }

    function test_ExecuteFeeChange() public {
        uint256 initialFee = 0.5 ether;
        uint256 newFee = 1 ether;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, initialFee);
        announcer.proposeFeeChange(newFee);
        vm.stopPrank();

        vm.warp(block.timestamp + announcer.FEE_CHANGE_DELAY() + 1);

        vm.expectEmit(true, false, false, true);
        emit FeeChanged(initialFee, newFee);

        vm.prank(owner);
        announcer.executeFeeChange();

        assertEq(announcer.announceFee(), newFee);
        assertEq(announcer.pendingFee(), 0);
        assertEq(announcer.feeChangeTimestamp(), 0);
    }

    function test_ExecuteFeeChangeRevertTooSoon() public {
        uint256 initialFee = 0.5 ether;
        uint256 newFee = 1 ether;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, initialFee);
        announcer.proposeFeeChange(newFee);
        vm.warp(block.timestamp + announcer.FEE_CHANGE_DELAY() - 1);
        vm.expectRevert(StealthAnnouncer.FeeChangeTooSoon.selector);
        announcer.executeFeeChange();
        vm.stopPrank();
    }

    function test_CancelFeeChange() public {
        uint256 newFee = 1 ether;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.proposeFeeChange(newFee);
        vm.warp(block.timestamp + announcer.CANCEL_COOLDOWN());
        announcer.cancelFeeChange();
        vm.stopPrank();

        assertEq(announcer.pendingFee(), 0);
        assertEq(announcer.feeChangeTimestamp(), 0);
    }

    function test_CancelFeeChangeRevertNoProposal() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.NoProposal.selector);
        announcer.cancelFeeChange();
        vm.stopPrank();
    }

    function test_CancelFeeChangeCooldown() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.proposeFeeChange(1 ether);
        vm.warp(block.timestamp + announcer.CANCEL_COOLDOWN());
        announcer.cancelFeeChange();
        announcer.proposeFeeChange(1 ether);
        vm.expectRevert(StealthAnnouncer.CooldownActive.selector);
        announcer.cancelFeeChange();
        vm.stopPrank();

        vm.warp(block.timestamp + announcer.CANCEL_COOLDOWN() + 1);

        vm.prank(owner);
        announcer.cancelFeeChange();
    }

    function test_ProposeFeeChangeRevertProposalPending() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.proposeFeeChange(1 ether);
        vm.expectRevert(StealthAnnouncer.ProposalPending.selector);
        announcer.proposeFeeChange(2 ether);
        vm.stopPrank();
    }

    // ========== Fee Recipient Tests ==========

    function test_SetFeeRecipient() public {
        address newRecipient = makeAddr("newRecipient");

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectEmit(true, true, false, true);
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        announcer.setFeeRecipient(newRecipient);
        vm.stopPrank();

        assertEq(announcer.feeRecipient(), newRecipient);
    }

    function test_SetFeeRecipientRevertInvalidAddress() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.InvalidFeeRecipient.selector);
        announcer.setFeeRecipient(address(0));
        vm.stopPrank();
    }

    // ========== Fee Exemption Tests ==========

    function test_SetFeeExemption() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit FeeExemptionSet(alice, true);
        announcer.setFeeExemption(alice, true);
        vm.stopPrank();

        assertTrue(announcer.feeExempt(alice));
        assertEq(announcer.getEffectiveFee(alice), 0);
    }

    function test_BatchSetFeeExemption() public {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = exemptUser;

        vm.startPrank(owner);
        announcer.batchSetFeeExemption(accounts, true);
        vm.stopPrank();

        assertTrue(announcer.feeExempt(alice));
        assertTrue(announcer.feeExempt(bob));
        assertTrue(announcer.feeExempt(exemptUser));
    }

    function test_BatchSetFeeExemptionRevertTooMany() public {
        address[] memory accounts = new address[](257); // Max is 256

        vm.startPrank(owner);
        vm.expectRevert(StealthAnnouncer.TooMany.selector);
        announcer.batchSetFeeExemption(accounts, true);
        vm.stopPrank();
    }

    function test_BatchSetFeeExemptionRevertZeroAddress() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = address(0);

        vm.startPrank(owner);
        vm.expectRevert(StealthAnnouncer.InvalidFeeRecipient.selector);
        announcer.batchSetFeeExemption(accounts, true);
        vm.stopPrank();
    }

    // ========== Pause/Unpause Tests ==========

    function test_PauseFees() public {
        uint256 duration = 30 days;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectEmit(true, false, false, true);
        emit FeesPaused(owner, block.timestamp + duration);
        announcer.pauseFees(duration);
        vm.stopPrank();

        assertTrue(announcer.feePaused());
        assertEq(announcer.pauseUntil(), block.timestamp + duration);
    }

    function test_PauseFeesRevertTooLong() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.PauseTooLong.selector);
        announcer.pauseFees(31 days); // > 30 days max
        vm.stopPrank();
    }

    function test_PauseFeesRevertZeroDuration() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.InvalidDuration.selector);
        announcer.pauseFees(0);
        vm.stopPrank();
    }

    function test_UnpauseFees() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.pauseFees(30 days);
        vm.expectEmit(true, false, false, true);
        emit FeesUnpaused(owner);
        announcer.unpauseFees();
        vm.stopPrank();

        assertFalse(announcer.feePaused());
        assertEq(announcer.pauseUntil(), 0);
    }

    function test_UnpauseFeesRevertNotPaused() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        vm.expectRevert(StealthAnnouncer.NotPaused.selector);
        announcer.unpauseFees();
        vm.stopPrank();
    }

    function test_AutoUnpauseFees() public {
        uint256 duration = 7 days;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.pauseFees(duration);
        vm.stopPrank();

        vm.prank(alice);
        feeToken.approve(address(announcer), type(uint256).max);

        vm.warp(block.timestamp + duration + 1);

        // Auto-unpause should occur during announce
        vm.prank(alice);
        announcer.announce(validEphemeralKey, address(0x1234), 100 ether, "0x");

        assertFalse(announcer.feePaused());
        assertEq(announcer.pauseUntil(), 0);
    }

    // ========== Ownership Tests ==========

    function test_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        announcer.transferOwnership(newOwner);

        assertEq(announcer.owner(), newOwner);
    }

    function test_TransferOwnershipRevertInvalidOwner() public {
        vm.prank(owner);
        vm.expectRevert(StealthAnnouncer.InvalidOwner.selector);
        announcer.transferOwnership(address(0));
    }

    // ========== View Function Tests ==========

    function test_GetEffectiveFee() public {
        uint256 fee = 0.5 ether;

        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, fee);
        announcer.setFeeExemption(exemptUser, true);
        vm.stopPrank();

        assertEq(announcer.getEffectiveFee(alice), fee);
        assertEq(announcer.getEffectiveFee(exemptUser), 0);
    }

    function test_CanExecuteFeeChange() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        announcer.proposeFeeChange(1 ether);
        vm.stopPrank();

        assertFalse(announcer.canExecuteFeeChange());

        vm.warp(block.timestamp + announcer.FEE_CHANGE_DELAY() + 1);

        assertTrue(announcer.canExecuteFeeChange());
    }

    function test_FeesEnabled() public {
        vm.prank(owner);
        assertFalse(announcer.feesEnabled());

        vm.prank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        assertTrue(announcer.feesEnabled());
    }

    function test_FeesActive() public {
        vm.startPrank(owner);
        announcer.initializeFees(address(feeToken), feeRecipient, 0.5 ether);
        assertTrue(announcer.feesActive());
        announcer.pauseFees(30 days);
        assertFalse(announcer.feesActive());
        vm.warp(block.timestamp + 30 days + 1);
        assertTrue(announcer.feesActive()); // Auto-unpaused
        vm.stopPrank();
    }

}
