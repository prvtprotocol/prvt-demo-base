// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal ERC20Permit interface
interface IERC20Permit {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/// @title StealthAnnouncer — broadcast ephemeral pubkeys with optional fees
/// @notice V2: Supports announcement fees in PRVT for sustainable operations
/// @dev Timelock-protected fee changes, permit support, pausable fee collection
contract StealthAnnouncer {
    using SafeERC20 for IERC20;
    
    // ========== State Variables ==========
    
    IERC20Permit public feeToken; // PRVT token (can be zero address for no fees)
    address public feeRecipient;
    address public owner;
    
    uint256 public announceFee; // Fee in PRVT wei (0 = no fee)
    uint256 public constant MAX_FEE = 10 ether; // 10 PRVT max
    
    // Fee change timelock
    uint256 public pendingFee;
    uint256 public feeChangeTimestamp;
    uint256 public constant FEE_CHANGE_DELAY = 7 days;
    uint256 public lastCancellation;
    uint256 public constant CANCEL_COOLDOWN = 1 days;
    
    // Fee exemptions (enterprise, partners, grants)
    mapping(address => bool) public feeExempt;
    
    // Fees pause control with time limit
    bool public feePaused;
    uint256 public pauseUntil;
    uint256 public constant MAX_PAUSE_DURATION = 30 days;
    
    // Initialization flag
    bool private _initialized;
    
    // ========== Events ==========
    
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
    
    // ========== Errors ==========
    
    error OnlyOwner();
    error FeeTooHigh();
    error FeeChangeTooSoon();
    error InvalidEphemeralKey();
    error InvalidFeeRecipient();
    error TransferFailed();
    error ReentrancyGuard();
    error ProposalPending();
    error AlreadyInitialized();
    error NotInitialized();
    error InvalidFeeToken();
    error TooMany();
    error InvalidOwner();
    error NoProposal();
    error NotPaused();
    error PauseTooLong();
    error InvalidDuration();
    error CooldownActive();
    
    // ========== Constructor ==========
    
    constructor() {
        owner = msg.sender;
        announceFee = 0;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // Simple reentrancy guard
    uint256 private locked = 1;
    modifier nonReentrant() {
        if (locked != 1) revert ReentrancyGuard();
        locked = 2;
        _;
        locked = 1;
    }
    
    modifier whenInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }
    
    // ========== Internal Functions ==========
    
    /// @notice Auto-unpause fees if pause duration has expired
    /// @dev Internal helper to avoid code duplication
    function _checkAndUnpauseFees() internal {
        if (feePaused && block.timestamp >= pauseUntil) {
            feePaused = false;
            pauseUntil = 0;
            emit FeesUnpaused(address(0)); // address(0) indicates auto-unpause
        }
    }
    
    // ========== Core Functions ==========
    
    /// @notice Announce stealth payment (backward compatible, free if no fee set)
    /// @param ephemeralPubkey Ephemeral public key (65 bytes uncompressed secp256k1)
    /// @param token Token address being sent
    /// @param amount Amount being sent
    /// @param hint Optional hint data
    /// @dev Validates format (65 bytes, 0x04 prefix, non-zero) but NOT secp256k1 curve membership
    /// @dev Invalid keys just result in wasted announcements (harmless for announcement-only contract)
    function announce(
        bytes calldata ephemeralPubkey,
        address token,
        uint256 amount,
        bytes calldata hint
    ) external nonReentrant {
        if (ephemeralPubkey.length != 65) revert InvalidEphemeralKey();
        if (ephemeralPubkey[0] != 0x04) revert InvalidEphemeralKey();
        if (_isZeroKey(ephemeralPubkey)) revert InvalidEphemeralKey();
        
        // Auto-unpause if pause duration expired
        _checkAndUnpauseFees();
        
        // Cache storage reads for gas optimization
        uint256 _announceFee = announceFee;
        bool _feePaused = feePaused;
        address _feeToken = address(feeToken);
        bool _exempt = feeExempt[msg.sender];
        address _feeRecipient = feeRecipient;
        
        // Collect fee if active (CEI pattern: emit events before external calls)
        if (!_feePaused && _feeToken != address(0) && _announceFee > 0 && !_exempt) {
            emit FeeCollected(msg.sender, _announceFee);
            IERC20(_feeToken).safeTransferFrom(msg.sender, _feeRecipient, _announceFee);
        }
        
        emit StealthPayment(ephemeralPubkey, token, amount, hint);
    }
    
    /// @notice Announce with permit (no prior approval needed)
    /// @param ephemeralPubkey Ephemeral public key (65 bytes uncompressed secp256k1)
    /// @param token Token address
    /// @param amount Amount
    /// @param hint Hint data
    /// @param deadline Permit deadline
    /// @param v Signature v
    /// @param r Signature r
    /// @param s Signature s
    /// @dev Token's EIP-2612 nonce provides replay protection - no custom tracking needed
    /// @dev Validates format (65 bytes, 0x04 prefix, non-zero) but NOT secp256k1 curve membership
    function announceWithPermit(
        bytes calldata ephemeralPubkey,
        address token,
        uint256 amount,
        bytes calldata hint,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        if (ephemeralPubkey.length != 65) revert InvalidEphemeralKey();
        if (ephemeralPubkey[0] != 0x04) revert InvalidEphemeralKey();
        if (_isZeroKey(ephemeralPubkey)) revert InvalidEphemeralKey();
        
        // Auto-unpause if pause duration expired
        _checkAndUnpauseFees();
        
        // Cache storage reads for gas optimization
        uint256 _announceFee = announceFee;
        bool _feePaused = feePaused;
        address _feeToken = address(feeToken);
        bool _exempt = feeExempt[msg.sender];
        address _feeRecipient = feeRecipient;
        
        // Collect fee via permit if active (CEI pattern: emit events before external calls)
        if (!_feePaused && _feeToken != address(0) && _announceFee > 0 && !_exempt) {
            // Try permit first; if it fails (frontrun), check if allowance exists
            try feeToken.permit(msg.sender, address(this), _announceFee, deadline, v, r, s) {
                // Permit succeeded
            } catch {
                // Permit may have been frontrun or invalid - check allowance as fallback
                if (IERC20(_feeToken).allowance(msg.sender, address(this)) < _announceFee) {
                    revert TransferFailed(); // No permit and insufficient allowance
                }
                // Allowance exists, proceed with transfer
            }
            
            emit FeeCollected(msg.sender, _announceFee);
            IERC20(_feeToken).safeTransferFrom(msg.sender, _feeRecipient, _announceFee);
        }
        
        emit StealthPayment(ephemeralPubkey, token, amount, hint);
    }
    
    // ========== Admin Functions ==========
    
    /// @notice Initialize fee system (one-time setup)
    /// @param _feeToken PRVT token address
    /// @param _feeRecipient Fee recipient (treasury)
    /// @param _initialFee Initial fee (e.g., 0.5 PRVT)
    function initializeFees(address _feeToken, address _feeRecipient, uint256 _initialFee) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (_initialized) revert AlreadyInitialized();
        if (_feeToken == address(0)) revert InvalidFeeToken();
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();
        if (_initialFee > MAX_FEE) revert FeeTooHigh();
        
        _initialized = true;
        feeToken = IERC20Permit(_feeToken);
        feeRecipient = _feeRecipient;
        announceFee = _initialFee;
        
        emit FeeTokenSet(_feeToken);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        if (_initialFee > 0) {
            emit FeeChanged(0, _initialFee);
        }
    }
    
    /// @notice Propose fee change (7-day timelock)
    /// @param newFee New announcement fee
    /// @dev Prevents proposal overwriting - must execute or cancel existing proposal first
    function proposeFeeChange(uint256 newFee) external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (newFee > MAX_FEE) revert FeeTooHigh();
        // Strict check: cannot propose if ANY proposal exists (prevents timelock bypass)
        if (feeChangeTimestamp != 0) revert ProposalPending();
        
        pendingFee = newFee;
        feeChangeTimestamp = block.timestamp + FEE_CHANGE_DELAY;
        
        emit FeeChangeProposed(newFee, feeChangeTimestamp);
    }
    
    /// @notice Cancel pending fee change
    /// @dev Allows creating new proposal without waiting for timelock
    /// @dev Cooldown prevents rapid cancellation/proposal cycles that could confuse users
    function cancelFeeChange() external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (feeChangeTimestamp == 0) revert NoProposal();
        if (block.timestamp < lastCancellation + CANCEL_COOLDOWN) revert CooldownActive();
        
        uint256 oldFee = pendingFee;
        uint256 oldTimestamp = feeChangeTimestamp;
        
        lastCancellation = block.timestamp;
        pendingFee = 0;
        feeChangeTimestamp = 0;
        
        emit FeeChangeCancelled(oldFee, oldTimestamp);
    }
    
    /// @notice Execute pending fee change (after timelock)
    function executeFeeChange() external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (feeChangeTimestamp == 0 || block.timestamp < feeChangeTimestamp) revert FeeChangeTooSoon();
        
        uint256 oldFee = announceFee;
        uint256 newFee = pendingFee;
        announceFee = newFee;
        
        pendingFee = 0;
        feeChangeTimestamp = 0;
        
        emit FeeChanged(oldFee, newFee);
    }
    
    /// @notice Set fee recipient
    /// @param newRecipient New fee recipient address
    function setFeeRecipient(address newRecipient) external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (newRecipient == address(0)) revert InvalidFeeRecipient();
        
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        
        emit FeeRecipientChanged(oldRecipient, newRecipient);
    }
    
    /// @notice Set fee exemption status
    /// @param account Account to exempt or unexempt
    /// @param exempt True to exempt, false to charge fees
    /// @dev Can be called before initialization to pre-configure exemptions
    function setFeeExemption(address account, bool exempt) external {
        if (msg.sender != owner) revert OnlyOwner();
        feeExempt[account] = exempt;
        emit FeeExemptionSet(account, exempt);
    }
    
    /// @notice Batch set fee exemptions
    /// @param accounts Array of accounts
    /// @param exempt Exemption status for all
    function batchSetFeeExemption(address[] calldata accounts, bool exempt) external {
        if (msg.sender != owner) revert OnlyOwner();
        uint256 len = accounts.length;
        if (len > 256) revert TooMany();
        for (uint256 i = 0; i < len;) {
            address account = accounts[i];
            if (account == address(0)) revert InvalidFeeRecipient(); // Reuse error for zero address
            feeExempt[account] = exempt;
            emit FeeExemptionSet(account, exempt);
            unchecked { ++i; }
        }
    }
    
    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (newOwner == address(0)) revert InvalidOwner();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
    
    // ========== View Functions ==========
    
    /// @notice Get effective fee for an account (0 if exempt or not configured)
    /// @param account Account to check
    /// @return Effective announcement fee
    function getEffectiveFee(address account) external view returns (uint256) {
        if (address(feeToken) == address(0) || feeExempt[account]) {
            return 0;
        }
        return announceFee;
    }
    
    /// @notice Check if fee change is ready to execute
    /// @return True if pending fee can be executed
    function canExecuteFeeChange() external view returns (bool) {
        return feeChangeTimestamp > 0 && block.timestamp >= feeChangeTimestamp;
    }

    /// @notice Pause fee collection (emergency, max 30 days)
    /// @param duration Pause duration in seconds (max 30 days)
    /// @dev Prevents indefinite pause that could defeat timelock purpose
    function pauseFees(uint256 duration) external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (duration == 0) revert InvalidDuration();
        if (duration > MAX_PAUSE_DURATION) revert PauseTooLong();
        
        feePaused = true;
        pauseUntil = block.timestamp + duration;
        emit FeesPaused(msg.sender, pauseUntil);
    }

    /// @notice Unpause fee collection
    /// @dev Only owner can unpause fees early (auto-unpause after pauseUntil)
    function unpauseFees() external whenInitialized {
        if (msg.sender != owner) revert OnlyOwner();
        if (!feePaused) revert NotPaused();
        
        feePaused = false;
        pauseUntil = 0;
        emit FeesUnpaused(msg.sender);
    }
    
    /// @notice Check if fees are enabled
    /// @return True if fee system is initialized
    function feesEnabled() external view returns (bool) {
        return address(feeToken) != address(0) && announceFee > 0;
    }
    
    /// @notice Check if fees are currently being collected
    /// @return True if fees are active (not paused or pause expired)
    /// @dev Useful for off-chain tracking and UI display
    function feesActive() public view returns (bool) {
        return !feePaused || block.timestamp >= pauseUntil;
    }
    
    /// @notice Check if fee system has been initialized
    /// @return True if fee system is initialized
    function isInitialized() external view returns (bool) {
        return _initialized;
    }
    
    /// @notice Check if ephemeral key is all zeros after the 0x04 prefix
    /// @param key Ephemeral public key to validate (must be 65 bytes)
    /// @return True if key is zero (invalid)
    /// @dev Optimized with assembly for gas efficiency (checks in 32-byte chunks)
    function _isZeroKey(bytes calldata key) internal pure returns (bool) {
        // key.length is validated by caller to be exactly 65 bytes
        // Check bytes 1-64 (skip byte 0 which is the 0x04 prefix)
        bytes32 chunk1;
        bytes32 chunk2;
        
        assembly {
            // Load bytes 1-32
            chunk1 := calldataload(add(key.offset, 1))
            // Load bytes 33-64
            chunk2 := calldataload(add(key.offset, 33))
        }
        
        return chunk1 == 0 && chunk2 == 0;
    }
}
