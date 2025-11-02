# PRVT Demo - Base Sepolia Transactions

This document contains links to on-chain transactions demonstrating the PRVT stealth address system.

## 📋 Contract Addresses

- **StealthRegistry**: [0xA4cd92f81596F55D78227F0f57DF7D105432407F](https://sepolia.basescan.org/address/0xA4cd92f81596F55D78227F0f57DF7D105432407F)
- **StealthAnnouncer**: [0xf1Df5d9725A54a968f65365Cc84ddE3d7773ae63](https://sepolia.basescan.org/address/0xf1Df5d9725A54a968f65365Cc84ddE3d7773ae63)
- **GasTank**: [0x93335Def5273Fa05F6cbba431E1Ca1CB89b16514](https://sepolia.basescan.org/address/0x93335Def5273Fa05F6cbba431E1Ca1CB89b16514)

See `ADDRESSES_BASE_SEPOLIA.json` for complete deployment details.

## 🔗 Demo Transactions

### 1. Key Registration
- **Function**: `setKeys(bytes calldata viewingKey, bytes calldata spendingKey)`
- **Transaction**: [0x957c890255cea702cb9aed2e63ceb2d72e041944001104802439c6ac11dc6ddb](https://sepolia.basescan.org/tx/0x957c890255cea702cb9aed2e63ceb2d72e041944001104802439c6ac11dc6ddb)
- **Description**: Register viewing and spending keys for stealth address receipt
- **Contract**: StealthRegistry

### 2. Ephemeral Key Announcement
- **Function**: `announce(bytes calldata ephemeralPubkey, address token, uint256 amount, bytes calldata hint)`
- **Transaction**: [0x4a094afe3084857e7a13bec9072cb22ad737bdf96299668eeeb340ba8a947809](https://sepolia.basescan.org/tx/0x4a094afe3084857e7a13bec9072cb22ad737bdf96299668eeeb340ba8a947809)
- **Description**: Broadcast ephemeral public key for stealth payment
- **Contract**: StealthAnnouncer

### 3. GasTank Deposit & Withdrawal
- **Function**: `deposit(bytes32 h)` → `withdraw(bytes calldata secret)`
- **Deposit TX**: [0x52558611cee285f85f2c5468b7ecdec5718eb852c55e0e0f6999a3af4acba339](https://sepolia.basescan.org/tx/0x52558611cee285f85f2c5468b7ecdec5718eb852c55e0e0f6999a3af4acba339)
- **Withdraw TX**: [0x86943b55969c7090cebd25c04a656d64f9f6a17165d5ed907114df53f6c0f6b6](https://sepolia.basescan.org/tx/0x86943b55969c7090cebd25c04a656d64f9f6a17165d5ed907114df53f6c0f6b6)
- **Description**: Demonstrate unlinkable gas funding via hash commitments (0.001 ETH deposit → withdrawal)
- **Contract**: GasTank

## 📝 Instructions

1. Deploy contracts: `forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify`
2. Update `ADDRESSES_BASE_SEPOLIA.json` with deployed addresses
3. Run demo: `forge script script/Demo.s.sol --rpc-url base_sepolia --broadcast`
4. Copy transaction hashes from output
5. Update links in this file

## 🔍 Verifying on Basescan

All contracts should be verified and viewable on [Basescan](https://sepolia.basescan.org).

