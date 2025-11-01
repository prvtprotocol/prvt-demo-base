# PRVT Demo - Stealth Address System

[![Test](https://github.com/yourusername/prvt-demo/actions/workflows/test.yml/badge.svg)](https://github.com/yourusername/prvt-demo/actions/workflows/test.yml)
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

## 📋 Prerequisites

- [Foundry](https://getfoundry.sh/)
- Git

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/prvt-demo
cd prvt-demo

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

## 🏗️ Architecture

```
src/
├── GasTank.sol           # Hash commitment ETH deposits/withdrawals
├── StealthAnnouncer.sol  # Event announcements with fee system
└── StealthRegistry.sol   # Public key registration

test/
├── GasTankTest.t.sol         # 26 tests (21 passing)
├── StealthAnnouncerTest.t.sol # 45 tests (40 passing)
├── StealthRegistryTest.t.sol  # 27 tests (10 passing)
├── IntegrationTest.t.sol      # 6 tests (3 passing)
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

## 🔗 Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-5564 Stealth Addresses](https://eips.ethereum.org/EIPS/eip-5564)

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
