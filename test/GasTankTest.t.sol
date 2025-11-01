// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {GasTank} from "../src/GasTank.sol";

contract GasTankTest is Test {
    GasTank public gasTank;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public recipient = makeAddr("recipient");

    bytes public constant SECRET1 = "secret123456789012345678901234567890"; // 32 bytes
    bytes public constant SECRET2 = "secret223456789012345678901234567890"; // 32 bytes
    bytes public constant SECRET3 = "secret323456789012345678901234567890"; // 32 bytes

    event Deposited(bytes32 indexed h, uint256 amount, address from);
    event Withdrawn(bytes32 indexed h, uint256 amount, address indexed to);
    event BatchWithdrawn(address indexed to, uint256 count, uint256 totalAmount);

    function setUp() public {
        gasTank = new GasTank();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(recipient, 100 ether);
    }

    // ========== Deposit Tests ==========

    function test_Deposit() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.expectEmit(true, false, false, true);
        emit Deposited(hash, amount, alice);

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        assertEq(gasTank.balanceOf(hash), amount);
        assertEq(address(gasTank).balance, amount);
    }

    function test_DepositRevertZeroValue() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));

        vm.prank(alice);
        vm.expectRevert(GasTank.NoValue.selector);
        gasTank.deposit{value: 0}(hash);
    }

    function test_DepositRevertHashAlreadyUsed() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        vm.prank(bob);
        vm.expectRevert(GasTank.HashAlreadyUsed.selector);
        gasTank.deposit{value: amount}(hash);
    }

    function test_DepositMultipleHashes() public {
        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET2, recipient));
        bytes32 hash3 = keccak256(abi.encodePacked(SECRET3, recipient));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 2 ether}(hash2);
        gasTank.deposit{value: 3 ether}(hash3);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(hash1), 1 ether);
        assertEq(gasTank.balanceOf(hash2), 2 ether);
        assertEq(gasTank.balanceOf(hash3), 3 ether);
        assertEq(address(gasTank).balance, 6 ether);
    }

    function test_DepositAfterWithdraw() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        // Recipient deposits and withdraws successfully
        vm.startPrank(recipient);
        gasTank.deposit{value: amount}(hash);
        gasTank.withdraw(SECRET1);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(hash), 0);
        assertEq(address(gasTank).balance, 0);

        // Re-depositing the same hash after withdrawal should succeed (balance was reset to zero)
        vm.prank(recipient);
        gasTank.deposit{value: amount}(hash);

        assertEq(gasTank.balanceOf(hash), amount);
        assertEq(address(gasTank).balance, amount);
    }

    function test_DepositDifferentRecipientsSameSecret() public {
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");

        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient1));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET1, recipient2));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 1 ether}(hash2);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(hash1), 1 ether);
        assertEq(gasTank.balanceOf(hash2), 1 ether);
    }

    function test_DepositReceiveRevert() public {
        (bool success, bytes memory data) = address(gasTank).call{value: 1 ether}("");
        assertFalse(success);
        assertEq(bytes4(data), GasTank.UseDeposit.selector);
    }

    // ========== Withdraw Tests ==========

    function test_Withdraw() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        uint256 balanceBefore = recipient.balance;

        vm.expectEmit(true, true, false, true);
        emit Withdrawn(hash, amount, recipient);

        vm.prank(recipient);
        gasTank.withdraw(SECRET1);

        assertEq(recipient.balance, balanceBefore + amount);
        assertEq(gasTank.balanceOf(hash), 0);
        assertEq(address(gasTank).balance, 0);
    }

    function test_WithdrawRevertNothingToWithdraw() public {
        vm.prank(recipient);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.withdraw(SECRET1);
    }

    function test_WithdrawRevertWrongSecret() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        bytes memory wrongSecret = "wrong_secret123456789012345678901234567";
        vm.prank(recipient);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.withdraw(wrongSecret);
    }

    function test_WithdrawRevertWrongRecipient() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        // Bob tries to withdraw using alice's secret but with recipient bound
        vm.prank(bob);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.withdraw(SECRET1);
    }

    function test_WithdrawMultipleTimes() public {
        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET2, recipient));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 2 ether}(hash2);
        vm.stopPrank();

        uint256 balanceBefore = recipient.balance;

        vm.startPrank(recipient);
        gasTank.withdraw(SECRET1);
        gasTank.withdraw(SECRET2);
        vm.stopPrank();

        assertEq(recipient.balance, balanceBefore + 3 ether);
        assertEq(gasTank.balanceOf(hash1), 0);
        assertEq(gasTank.balanceOf(hash2), 0);
    }

    function test_WithdrawReentrancyProtection() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        ReentrancyAttacker attacker = new ReentrancyAttacker(gasTank);
        vm.deal(address(attacker), 1 ether);

        bytes memory attackerSecret = attacker.secret();
        bytes32 attackerHash = keccak256(abi.encodePacked(attackerSecret, address(attacker)));
        vm.prank(alice);
        gasTank.deposit{value: amount}(attackerHash);

        // Attacker tries to reenter during withdraw (transfer fails, protecting funds)
        vm.startPrank(address(attacker));
        vm.expectRevert(GasTank.TransferFailed.selector);
        gasTank.withdraw(attackerSecret);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(attackerHash), amount);
    }

    function test_WithdrawTransferFails() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        // Create a contract that rejects ETH
        RejectingReceiver rejector = new RejectingReceiver();
        bytes32 rejectorHash = keccak256(abi.encodePacked(SECRET1, address(rejector)));

        vm.prank(alice);
        gasTank.deposit{value: amount}(rejectorHash);

        vm.prank(address(rejector));
        vm.expectRevert(GasTank.TransferFailed.selector);
        gasTank.withdraw(SECRET1);

        // State should remain intact since the transaction reverted
        assertEq(gasTank.balanceOf(rejectorHash), amount);
    }

    // ========== Batch Withdraw Tests ==========

    function test_BatchWithdraw() public {
        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET2, recipient));
        bytes32 hash3 = keccak256(abi.encodePacked(SECRET3, recipient));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 2 ether}(hash2);
        gasTank.deposit{value: 3 ether}(hash3);
        vm.stopPrank();

        uint256 balanceBefore = recipient.balance;
        bytes[] memory secrets = new bytes[](3);
        secrets[0] = SECRET1;
        secrets[1] = SECRET2;
        secrets[2] = SECRET3;

        vm.expectEmit(true, true, false, true);
        emit BatchWithdrawn(recipient, 3, 6 ether);

        vm.prank(recipient);
        gasTank.batchWithdraw(secrets);

        assertEq(recipient.balance, balanceBefore + 6 ether);
        assertEq(gasTank.balanceOf(hash1), 0);
        assertEq(gasTank.balanceOf(hash2), 0);
        assertEq(gasTank.balanceOf(hash3), 0);
    }

    function test_BatchWithdrawPartialValid() public {
        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET2, recipient));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 2 ether}(hash2);
        vm.stopPrank();

        bytes[] memory secrets = new bytes[](3);
        secrets[0] = SECRET1;
        secrets[1] = SECRET2;
        secrets[2] = "invalid_secret123456789012345678901234567"; // Invalid secret, silently skipped

        vm.prank(recipient);
        gasTank.batchWithdraw(secrets);

        assertEq(gasTank.balanceOf(hash1), 0);
        assertEq(gasTank.balanceOf(hash2), 0);
    }

    function test_BatchWithdrawEmptyArray() public {
        bytes[] memory secrets = new bytes[](0);

        vm.prank(recipient);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.batchWithdraw(secrets);
    }

    function test_BatchWithdrawTooMany() public {
        bytes[] memory secrets = new bytes[](257); // Max is 256

        for (uint256 i = 0; i < 257; i++) {
            secrets[i] = abi.encodePacked("secret", i);
        }

        vm.prank(recipient);
        vm.expectRevert(GasTank.TooMany.selector);
        gasTank.batchWithdraw(secrets);
    }

    function test_BatchWithdrawAllInvalid() public {
        bytes[] memory secrets = new bytes[](3);
        secrets[0] = "invalid1_secret123456789012345678901234567";
        secrets[1] = "invalid2_secret123456789012345678901234567";
        secrets[2] = "invalid3_secret123456789012345678901234567";

        vm.prank(recipient);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.batchWithdraw(secrets);
    }

    function test_BatchWithdrawReentrancyProtection() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(gasTank);
        vm.deal(address(attacker), 1 ether);

        bytes memory attackerSecret = attacker.secret();
        bytes32 hash1 = keccak256(abi.encodePacked(attackerSecret, address(attacker)));
        vm.prank(alice);
        gasTank.deposit{value: 1 ether}(hash1);

        bytes[] memory secrets = new bytes[](1);
        secrets[0] = attackerSecret;

        vm.startPrank(address(attacker));
        vm.expectRevert(GasTank.TransferFailed.selector);
        gasTank.batchWithdraw(secrets);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(hash1), 1 ether);
    }

    // ========== View Function Tests ==========

    function test_BalanceOf() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1.5 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        assertEq(gasTank.balanceOf(hash), amount);
        assertEq(gasTank.balanceOf(keccak256(abi.encodePacked(SECRET2, recipient))), 0);
    }

    function test_ComputeHash() public view {
        bytes memory secret = SECRET1;
        address user = recipient;

        bytes32 expectedHash = keccak256(abi.encodePacked(secret, user));
        bytes32 computedHash = gasTank.computeHash(secret, user);

        assertEq(computedHash, expectedHash);
    }

    // ========== Edge Cases & Security ==========

    function test_DepositMaximumValue() public {
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 maxValue = type(uint256).max;

        vm.deal(alice, maxValue);
        vm.prank(alice);
        gasTank.deposit{value: maxValue}(hash);

        assertEq(gasTank.balanceOf(hash), maxValue);
    }

    function test_WithdrawAfterDepositMultipleRecipients() public {
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");

        bytes32 hash1 = keccak256(abi.encodePacked(SECRET1, recipient1));
        bytes32 hash2 = keccak256(abi.encodePacked(SECRET1, recipient2));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 2 ether}(hash2);
        vm.stopPrank();

        uint256 balance1Before = recipient1.balance;
        uint256 balance2Before = recipient2.balance;

        vm.prank(recipient1);
        gasTank.withdraw(SECRET1);

        vm.prank(recipient2);
        gasTank.withdraw(SECRET1);

        assertEq(recipient1.balance, balance1Before + 1 ether);
        assertEq(recipient2.balance, balance2Before + 2 ether);
    }

    function test_SecretLengthVariations() public {
        // Test with different secret lengths
        bytes memory shortSecret = "short"; // 5 bytes
        bytes memory mediumSecret = "medium_length_secret12345"; // 25 bytes
        bytes memory longSecret = "very_long_secret_1234567890123456789012345678901234567890"; // 50 bytes

        bytes32 hash1 = keccak256(abi.encodePacked(shortSecret, recipient));
        bytes32 hash2 = keccak256(abi.encodePacked(mediumSecret, recipient));
        bytes32 hash3 = keccak256(abi.encodePacked(longSecret, recipient));

        vm.startPrank(alice);
        gasTank.deposit{value: 1 ether}(hash1);
        gasTank.deposit{value: 1 ether}(hash2);
        gasTank.deposit{value: 1 ether}(hash3);
        vm.stopPrank();

        vm.startPrank(recipient);
        gasTank.withdraw(shortSecret);
        gasTank.withdraw(mediumSecret);
        gasTank.withdraw(longSecret);
        vm.stopPrank();

        assertEq(gasTank.balanceOf(hash1), 0);
        assertEq(gasTank.balanceOf(hash2), 0);
        assertEq(gasTank.balanceOf(hash3), 0);
    }

    function test_FrontRunningProtection() public {
        // Hash includes recipient, so front-runner can't withdraw
        bytes32 hash = keccak256(abi.encodePacked(SECRET1, recipient));
        uint256 amount = 1 ether;

        vm.prank(alice);
        gasTank.deposit{value: amount}(hash);

        // Front-runner sees the hash but can't withdraw without knowing secret + recipient binding
        bytes32 frontRunnerHash = keccak256(abi.encodePacked(SECRET1, bob));
        assertEq(gasTank.balanceOf(frontRunnerHash), 0);

        // Bob cannot withdraw using alice's deposit
        vm.prank(bob);
        vm.expectRevert(GasTank.NothingToWithdraw.selector);
        gasTank.withdraw(SECRET1);
    }
}

// ========== Helper Contracts ==========

contract ReentrancyAttacker {
    GasTank public gasTank;
    bytes public constant SECRET = "attacker_secret123456789012345678901234567";

    constructor(GasTank _gasTank) {
        gasTank = _gasTank;
    }

    function secret() external pure returns (bytes memory) {
        return SECRET;
    }

    receive() external payable {
        // Try to reenter during withdraw
        gasTank.withdraw(SECRET);
    }
}

contract RejectingReceiver {
    receive() external payable {
        revert("Rejecting ETH");
    }

    fallback() external payable {
        revert("Rejecting ETH");
    }
}
