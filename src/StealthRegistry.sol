// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StealthRegistry — publish viewing & spending public keys (65B uncompressed secp256k1)
/// @notice Supports key rotation via clearing and re-registration
/// @dev Validates format (65 bytes, 0x04 prefix, non-zero) but NOT secp256k1 curve membership
/// @dev Invalid keys will not work off-chain; users are responsible for providing valid points
contract StealthRegistry {
    struct Keys { 
        bytes viewingPub; 
        bytes spendingPub; 
    }
    
    mapping(address => Keys) private _keys;

    /// @notice Emitted when keys are set or updated
    /// @dev Integrators SHOULD validate curve membership off-chain before use
    /// @param user Account whose keys were set
    /// @param viewingPub Viewing public key (65B uncompressed)
    /// @param spendingPub Spending public key (65B uncompressed)
    /// @param isUpdate True if overwriting existing keys
    event KeysSet(address indexed user, bytes viewingPub, bytes spendingPub, bool isUpdate);
    event KeysCleared(address indexed user);
    
    error InvalidKey();
    error SameKeyReuse();

    /// @notice Set stealth keys (65-byte uncompressed secp256k1 public keys)
    /// @dev WARNING: Replacing keys may render previously derived stealth addresses unspendable.
    ///      Rotate keys only after sweeping funds or when operationally safe.
    /// @dev Front-running: register keys using private RPC to minimize mempool observation.
    /// @param viewingPub Viewing public key (0x04 + 64 bytes)
    /// @param spendingPub Spending public key (0x04 + 64 bytes)
    function setKeys(bytes calldata viewingPub, bytes calldata spendingPub) external {
        if (viewingPub.length != 65 || spendingPub.length != 65) revert InvalidKey();
        // Enforce uncompressed format marker and non-zero material
        if (viewingPub[0] != 0x04 || spendingPub[0] != 0x04) revert InvalidKey();
        if (_isZeroKey(viewingPub) || _isZeroKey(spendingPub)) revert InvalidKey();
        // Prevent using the same key for both roles (security best practice)
        if (keccak256(viewingPub) == keccak256(spendingPub)) revert SameKeyReuse();
        bool isUpdate = _keys[msg.sender].viewingPub.length > 0;
        _keys[msg.sender] = Keys({ 
            viewingPub: viewingPub, 
            spendingPub: spendingPub
        });
        emit KeysSet(msg.sender, viewingPub, spendingPub, isUpdate);
    }

    /// @notice Clear stealth keys (for key rotation or privacy reset)
    function clearKeys() external {
        delete _keys[msg.sender];
        emit KeysCleared(msg.sender);
    }

    /// @notice Get stealth keys for a user
    /// @return viewingPub Viewing public key
    /// @return spendingPub Spending public key
    function keys(address user) external view returns (bytes memory, bytes memory) {
        Keys storage k = _keys[user];
        return (k.viewingPub, k.spendingPub);
    }

    /// @notice Check if user has registered keys
    /// @return True if user has registered keys
    function hasKeys(address user) external view returns (bool) {
        return _keys[user].viewingPub.length > 0;
    }

    /// @notice Contract version identifier (semantic versioning)
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @notice Check if key is all zeros after the 0x04 prefix
    /// @dev Optimized with assembly for gas efficiency (checks in 32-byte chunks)
    /// @dev SAFETY: calldataload beyond calldata length returns 0; key length is pre-validated to 65
    function _isZeroKey(bytes calldata key) internal pure returns (bool) {
        // Check bytes 1-64 (skip byte 0 which is the 0x04 prefix)
        bytes32 chunk1;
        bytes32 chunk2;
        assembly {
            chunk1 := calldataload(add(key.offset, 1))   // bytes 1..32
            chunk2 := calldataload(add(key.offset, 33))  // bytes 33..64
        }
        return chunk1 == 0 && chunk2 == 0;
    }
}

