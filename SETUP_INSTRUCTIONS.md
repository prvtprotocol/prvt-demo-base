# Setup Instructions for Compilation

## Prerequisites

1. **Install Foundry** (if not already installed):
   ```bash
   # On Windows (PowerShell)
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   
   # Or download from: https://github.com/foundry-rs/foundry/releases
   ```

2. **Install OpenZeppelin Contracts**:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts --no-commit
   ```

3. **Install forge-std** (if not already installed):
   ```bash
   forge install foundry-rs/forge-std --no-commit
   ```

## Compile

Once dependencies are installed, run:
```bash
forge build
```

## Run Tests

```bash
forge test
forge test -vvv  # For detailed output
forge test --match-contract GasTankTest  # Run specific test file
```

## Troubleshooting

If you get import errors:
- Verify `lib/openzeppelin-contracts/` exists
- Verify `lib/forge-std/` exists
- Check that `remappings.txt` contains the correct paths
