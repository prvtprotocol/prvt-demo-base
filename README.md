# PRVT Demo - Stealth Address System

[![Base Sepolia](https://img.shields.io/badge/network-Base%20Sepolia-blue)](https://sepolia.basescan.org/)
[![Tests Passing](https://github.com/prvtprotocol/prvt-demo-base/actions/workflows/test.yml/badge.svg)](https://github.com/prvtprotocol/prvt-demo-base/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.24-blue)](https://soliditylang.org/)

> ⚠️ **Security Warning:** This code has NOT been professionally audited. DO NOT use in production with real funds. See [SECURITY.md](SECURITY.md) for details.

A Foundry-based implementation of stealth address technology for private blockchain transactions using hash commitments and ephemeral keys.

## 🎯 Overview

This project implements three core contracts for privacy-preserving transactions:

### 1. **GasTank** - Unlinkable Gas Funding
Hash commitment-based ETH deposits for funding stealth address transactions without linking sender/recipient.

**Key Features:**
- Deposit ETH against hash: `h = keccak256(abi.encodePacked(secret, recipientAddress))`
- Withdraw by revealing secret (bound to recipient address)
- Batch withdrawals for gas efficiency
- Front-running protection via address binding
- CEI pattern + reentrancy guard

### 2. **StealthAnnouncer** - Event Broadcasting with Fees
Announces stealth payments with optional PRVT token fee system.

**Key Features:**
- Ephemeral public key announcements (65-byte secp256k1)
- EIP-2612 permit support for gasless fee payments
- Timelock-protected fee changes (7-day delay)
- Fee exemptions for partners/enterprises
- Pausable fee collection with time limits

### 3. **StealthRegistry** - Public Key Registry
Manages user stealth key registrations with validation.

**Key Features:**
- Viewing and spending key pairs (65-byte uncompressed secp256k1)
- Key rotation support via clear/reset
- Prevents same key reuse for both roles
- Gas-optimized zero-key checking

## 🌐 Connect & Socials

- **GitHub**: [@prvtprotocol](https://github.com/prvtprotocol/prvt-demo-base)
- **Twitter/X**: [@PRVTprotocol](https://x.com/PRVTprotocol)
- **TikTok**: [@prvtbase](https://www.tiktok.com/@prvtbase)
- **Reddit**: [u/Individual_Big9893](https://www.reddit.com/user/Individual_Big9893/)

## 📋 Prerequisites

- [Foundry](https://getfoundry.sh/)
- Git

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/prvtprotocol/prvt-demo-base
cd prvt-demo-base

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Check coverage
forge coverage
```

## 🎬 Quick Demo

### See It Live

Visit the verified contracts on Base Sepolia:

- **[StealthRegistry](https://sepolia.basescan.org/address/0xA4cd92f81596F55D78227F0f57DF7D105432407F)** - Public key registry
- **[StealthAnnouncer](https://sepolia.basescan.org/address/0xf1Df5d9725A54a968f65365Cc84ddE3d7773ae63)** - Ephemeral key announcements
- **[GasTank](https://sepolia.basescan.org/address/0x93335Def5273Fa05F6cbba431E1Ca1CB89b16514)** - Unlinkable gas funding

### Live Demo Transactions

View the complete stealth address flow on-chain:

1. **[Key Registration](https://sepolia.basescan.org/tx/0x957c890255cea702cb9aed2e63ceb2d72e041944001104802439c6ac11dc6ddb)** - Register viewing/spending keys
2. **[Ephemeral Announcement](https://sepolia.basescan.org/tx/0x4a094afe3084857e7a13bec9072cb22ad737bdf96299668eeeb340ba8a947809)** - Broadcast stealth payment
3. **[GasTank Deposit](https://sepolia.basescan.org/tx/0x52558611cee285f85f2c5468b7ecdec5718eb852c55e0e0f6999a3af4acba339)** - Unlinkable ETH deposit (0.001 ETH)
4. **[GasTank Withdraw](https://sepolia.basescan.org/tx/0x86943b55969c7090cebd25c04a656d64f9f6a17165d5ed907114df53f6c0f6b6)** - Secret reveal & withdrawal

### Reproduce Locally

Run the demo script to execute the same flow:

```bash
# Set up .env with PRIVATE_KEY and RPC_BASE_SEPOLIA
forge script script/Demo.s.sol --rpc-url base_sepolia --broadcast
```

Check the new transaction hashes on [Basescan](https://sepolia.basescan.org/).

## 🏗️ Architecture

```
src/
├── GasTank.sol           # Hash commitment ETH deposits/withdrawals
├── StealthAnnouncer.sol  # Event announcements with fee system
└── StealthRegistry.sol   # Public key registration

test/
├── GasTankTest.t.sol         # 26 tests
├── StealthAnnouncerTest.t.sol # 45 tests
├── StealthRegistryTest.t.sol  # 14 tests
├── IntegrationTest.t.sol      # 3 tests
└── mocks/
    └── MockERC20Permit.sol    # EIP-2612 test token
```

## 📊 Test Status

**Current:** 88/88 tests passing (100%)

Coverage (via `forge coverage --report summary --ir-minimum`):
- Lines: 92.3%
- Statements: 87.9%
- Branches: 73.2%
- Functions: 95.3%

Some tests are intentionally strict edge cases. Core functionality is fully tested and working.

```bash
# Run specific test file
forge test --match-contract GasTankTest

# Run with detailed output
forge test -vvv

# Run specific test
forge test --match-test test_Deposit
```

## 🔒 Security

### Implemented Protections
- ✅ CEI (Checks-Effects-Interactions) pattern
- ✅ Reentrancy guards
- ✅ Input validation
- ✅ Custom errors for gas efficiency
- ✅ Access control
- ✅ Timelock for parameter changes

### Privacy Considerations
- Hash commitments prevent linking without secret
- Ephemeral keys for one-time use
- Recommend using Flashbots/private RPCs
- Use round amounts for better anonymity sets
- Wait random time periods between deposit/withdrawal

**⚠️ See [SECURITY.md](SECURITY.md) for full security disclosure and limitations.**

## 🛠️ Configuration

### Environment Variables

Create `.env` file:

```env
PRIVATE_KEY=0x...
RPC_BASE_SEPOLIA=https://sepolia.base.org
ETHERSCAN_API_KEY=...
```

### Foundry Profile

`foundry.toml`:
- Solidity: 0.8.24
- Optimizer: enabled (200 runs)
- Via IR: true (for stack depth)
- EVM: Cancun

## 📦 Deployment

```bash
# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify

# Verify contracts
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id 84532
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines
- Write tests for new features
- Follow Solidity style guide
- Add NatSpec documentation
- Ensure `forge test` passes
- Update README if needed

## 📄 License

[MIT](LICENSE) - see LICENSE file for details

## 🔗 Resources & Links

### Documentation
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-5564 Stealth Addresses](https://eips.ethereum.org/EIPS/eip-5564)

### Social Media
- **GitHub**: [prvtprotocol/prvt-demo-base](https://github.com/prvtprotocol/prvt-demo-base)
- **Twitter/X**: [@PRVTprotocol](https://x.com/PRVTprotocol)
- **TikTok**: [@prvtbase](https://www.tiktok.com/@prvtbase)
- **Reddit**: [u/Individual_Big9893](https://www.reddit.com/user/Individual_Big9893/)

## ⚡ Gas Optimization

Contracts use:
- Custom errors (vs require strings)
- Calldata over memory
- Storage caching
- Via IR compilation
- Efficient data packing

Run gas report:
```bash
forge test --gas-report
forge coverage --report summary --ir-minimum
```

## 📝 TODO

- [ ] Professional third-party security audit
- [ ] Gas optimization audit & benchmarking report
- [ ] Frontend SDK (TypeScript)
- [ ] Mainnet deployment scripts
- [ ] Documentation site / whitepaper

## 🙏 Acknowledgments

Built with [Foundry](https://github.com/foundry-rs/foundry) and [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts).

---

**⚠️ DISCLAIMER:** This is experimental software. Use at your own risk. Not audited. Not production-ready.
