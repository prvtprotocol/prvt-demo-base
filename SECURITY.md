# Security Policy

## ⚠️ Security Disclaimer

**THIS CODE HAS NOT BEEN PROFESSIONALLY AUDITED.**

This is a demonstration project for educational purposes. DO NOT use in production with real funds without:

1. Professional security audit by reputable firm(s)
2. Comprehensive testing on testnets
3. Bug bounty program
4. Gradual rollout with value limits

## Known Limitations

### Privacy Considerations
- On-chain metadata can be analyzed
- Timing analysis may correlate transactions
- Amount analysis can link deposits/withdrawals
- Secrets are revealed permanently after withdrawal

### Security Assumptions
- Users must generate cryptographically secure random secrets
- Users must use private RPCs (Flashbots) for maximum privacy
- Users must never reuse secrets across deposits
- Lost secrets mean lost funds (no recovery mechanism by design)

## Reporting Vulnerabilities

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email: [your-email@example.com]
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

## Security Features Implemented

### Reentrancy Protection
- ✅ CEI (Checks-Effects-Interactions) pattern throughout
- ✅ NonReentrant modifiers on state-changing functions
- ✅ State updates before external calls

### Access Control
- ✅ Owner-only functions for admin operations
- ✅ Fee exemption system
- ✅ Timelock for fee changes (7 days)

### Input Validation
- ✅ All user inputs validated
- ✅ Key format validation (65-byte secp256k1)
- ✅ Zero address checks
- ✅ Amount validations

### Gas Optimization
- ✅ Custom errors instead of string reverts
- ✅ Storage caching in loops
- ✅ Efficient data structures

## Audit History

**Status:** Not audited

We welcome security researchers to review this code and report findings.

