# PRVT Demo - Base Sepolia Transactions

This document contains links to on-chain transactions demonstrating the PRVT stealth address system.

## 📋 Contract Addresses

Update these after deployment:

- **StealthRegistry**: [0x...](https://sepolia.basescan.org/address/0x...)
- **StealthAnnouncer**: [0x...](https://sepolia.basescan.org/address/0x...)
- **GasTank**: [0x...](https://sepolia.basescan.org/address/0x...)

See `ADDRESSES_BASE_SEPOLIA.json` for complete deployment details.

## 🔗 Demo Transactions

Update these transaction hashes after running `script/Demo.s.sol`:

### 1. Key Registration
- **Function**: `register()` / `setKeys()`
- **Transaction**: [0x...](https://sepolia.basescan.org/tx/0x...)
- **Description**: Register viewing and spending keys for stealth address receipt

### 2. Ephemeral Key Announcement
- **Function**: `announce(bytes calldata ephemeralPublicKey, uint256 fee)`
- **Transaction**: [0x...](https://sepolia.basescan.org/tx/0x...)
- **Description**: Broadcast ephemeral public key for stealth payment

### 3. GasTank Deposit & Withdrawal
- **Function**: `deposit(bytes32 hash)` → `withdraw(bytes32 secret, address recipient)`
- **Deposit TX**: [0x...](https://sepolia.basescan.org/tx/0x...)
- **Withdraw TX**: [0x...](https://sepolia.basescan.org/tx/0x...)
- **Description**: Demonstrate unlinkable gas funding via hash commitments

## 📝 Instructions

1. Deploy contracts: `forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify`
2. Update `ADDRESSES_BASE_SEPOLIA.json` with deployed addresses
3. Run demo: `forge script script/Demo.s.sol --rpc-url base_sepolia --broadcast`
4. Copy transaction hashes from output
5. Update links in this file

## 🔍 Verifying on Basescan

All contracts should be verified and viewable on [Basescan](https://sepolia.basescan.org).

