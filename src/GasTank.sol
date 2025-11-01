// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GasTank — Unlinkable Gas Funding via Hash Commitments
/// @notice Deposit ETH against a hash, withdraw by revealing the preimage
/// @dev PRIVACY CONSIDERATIONS:
/// - Hash commitment must include recipient: h = keccak256(abi.encodePacked(secret, recipientAddress))
/// - Use Flashbots/private RPC to submit withdrawals for maximum privacy
/// - Never reuse secrets across deposits
/// - Use round amounts (0.1, 0.5, 1.0 ETH) for better anonymity sets
/// - Wait random time periods between deposit and withdrawal
/// - Timing correlation can link addresses
/// - Deposit and withdrawal amounts are identical (linkable via amount analysis)
/// - Secret is revealed on-chain after withdrawal (permanent blockchain record)
/// @dev SECRET GENERATION:
/// - Must use cryptographically secure random bytes (≥32 bytes recommended)
/// - Never use predictable values (addresses, timestamps, passwords)
/// - Generate off-chain with secure RNG (crypto.getRandomValues)
/// - Never share or transmit secrets over insecure channels
/// @dev OVERFLOW PROTECTION:
/// - Solidity 0.8+ provides automatic overflow/underflow protection
/// - All arithmetic operations revert on overflow (except unchecked blocks)
/// - batchWithdraw() totalAmt uses checked addition (safe)
/// @dev FUNDS RECOVERY:
/// - Lost secrets mean lost funds - no recovery mechanism by design
/// - This is intentional for privacy preservation
/// @dev Uses CEI pattern and reentrancy guard for maximum safety
/// @dev Front-running protection via address binding in hash commitment
contract GasTank {
    mapping(bytes32 => uint256) public deposits; // h(secret, recipient) => wei
    
    // Reentrancy lock (belt-and-suspenders; CEI already prevents issues)
    uint256 private locked = 1;
    
    event Deposited(bytes32 indexed h, uint256 amount, address from); // 'from' not indexed for privacy
    event Withdrawn(bytes32 indexed h, uint256 amount, address indexed to);
    event BatchWithdrawn(address indexed to, uint256 count, uint256 totalAmount);

    error ReentrancyGuard();
    error NoValue();
    error NothingToWithdraw();
    error TransferFailed();
    error UseDeposit();
    error TooMany();
    error HashAlreadyUsed();

    modifier nonReentrant() {
        if (locked != 1) revert ReentrancyGuard();
        locked = 2;
        _;
        locked = 1;
    }

    receive() external payable {
        revert UseDeposit();
    }

    /// @notice Deposit ETH against a hash commitment
    /// @dev Hash must include recipient: h = keccak256(abi.encodePacked(secret, recipientAddress))
    /// @dev Prevents hash reuse for security - each hash can only be deposited once
    /// @dev After withdrawal, same hash COULD be deposited again (zero balance reset)
    /// @dev NEVER reuse secrets - generate fresh random bytes for each deposit
    /// @param h Hash of secret and recipient (keccak256(abi.encodePacked(secret, recipientAddress)))
    function deposit(bytes32 h) external payable {
        if (msg.value == 0) revert NoValue();
        if (deposits[h] != 0) revert HashAlreadyUsed(); // Prevent reuse/accumulation
        deposits[h] = msg.value;
        emit Deposited(h, msg.value, msg.sender);
    }

    /// @notice Withdraw by revealing the secret (bound to msg.sender)
    /// @dev Secret must be bound to recipient address in hash to prevent front-running
    /// @dev Zeroes balance before external call (CEI) + reentrancy guard
    /// @param secret Preimage of the hash (must match hash used in deposit)
    function withdraw(bytes calldata secret) external nonReentrant {
        bytes32 h = keccak256(abi.encodePacked(secret, msg.sender));
        uint256 amt = deposits[h];
        if (amt == 0) revert NothingToWithdraw();
        
        deposits[h] = 0; // CEI: zero state before external call
        
        (bool ok,) = msg.sender.call{value: amt}("");
        if (!ok) revert TransferFailed();
        
        emit Withdrawn(h, amt, msg.sender);
    }
    
    /// @notice Batch withdraw multiple commitments in one transaction
    /// @dev Gas efficient for withdrawing multiple small deposits
    /// @dev OVERFLOW PROTECTION: totalAmt uses checked addition (Solidity 0.8+)
    /// @dev Silently skips hashes with zero balance (no revert for invalid hashes)
    /// @dev GAS LIMIT: Max 256 = ~8M gas worst case. Consider smaller batches if gas prices high
    /// @param secrets Array of preimages (each bound to msg.sender)
    function batchWithdraw(bytes[] calldata secrets) external nonReentrant {
        uint256 len = secrets.length;
        if (len == 0) revert NothingToWithdraw();
        if (len > 256) revert TooMany();
        
        uint256 totalAmt = 0;
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < len;) {
            bytes32 h = keccak256(abi.encodePacked(secrets[i], msg.sender));
            uint256 amt = deposits[h];
            
            if (amt > 0) {
                deposits[h] = 0; // CEI: zero state before external call
                totalAmt += amt; // Checked addition - reverts on overflow (Solidity 0.8+)
                successCount++;
                emit Withdrawn(h, amt, msg.sender);
            }
            
            unchecked { ++i; } // Only increment is unchecked (safe, bounded)
        }
        
        if (successCount == 0) revert NothingToWithdraw();
        
        (bool ok,) = msg.sender.call{value: totalAmt}("");
        if (!ok) revert TransferFailed();
        
        emit BatchWithdrawn(msg.sender, successCount, totalAmt);
    }

    /// @notice Check balance for a hash commitment
    /// @param h Hash commitment (keccak256(abi.encodePacked(secret, recipientAddress)))
    /// @return Balance in wei
    function balanceOf(bytes32 h) external view returns (uint256) {
        return deposits[h];
    }
    
    /// @notice Compute hash commitment for a secret and recipient
    /// @dev ⚠️ EXPENSIVE: ~1000 gas. Always compute off-chain in production!
    /// @dev This function is for testing/verification only
    /// @param secret Secret preimage (≥32 bytes recommended)
    /// @param recipient Recipient address
    /// @return Hash commitment
    function computeHash(bytes calldata secret, address recipient) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret, recipient));
    }
}
