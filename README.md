# NairaBridgeManager

A UUPS-upgradeable smart contract system that bridges ERC-20 stablecoin deposits to fiat Naira payouts. Users deposit USDC/USDT on-chain; a trusted NestJS dispatcher executes gasless withdrawals authorised by EIP-712 signatures, triggering real Naira bank payouts via Paystack or Flutterwave.

---

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                     OFF-RAMP FLOW                       │
│                                                         │
│  User approves ERC-20 → depositCrypto()                 │
│          ↓                                              │
│  Contract holds tokens, emits CryptoDeposited           │
│          ↓                                              │
│  Alchemy Webhook → NestJS → Prisma balance credited     │
│          ↓                                              │
│  User signs EIP-712 withdrawal request (gasless)        │
│          ↓                                              │
│  NestJS dispatcher calls processGaslessWithdrawal()     │
│          ↓                                              │
│  Contract verifies signature → transfers to treasury    │
│          ↓                                              │
│  NestJS debits balance → triggers Naira bank payout     │
└─────────────────────────────────────────────────────────┘
```

---

## Architecture

The system is split into a thin orchestrator contract and four focused libraries. All business logic lives in the libraries; the main contract owns storage, roles, upgradeability, and pause state only.

```
contracts/
├── core/
│   └── NairaBridgeManager.sol    ← Thin orchestrator
└── libraries/
    ├── DepositLib.sol             ← depositCrypto logic
    ├── WithdrawalLib.sol          ← EIP-712 verification + withdrawal logic
    ├── TokenLib.sol               ← Token allowlist management
    └── ConfigLib.sol              ← Treasury + cap configuration
```

### NairaBridgeManager.sol

The main UUPS proxy contract. Owns ERC-7201 namespaced storage, AccessControl roles, pause state, and upgrade authorisation. Every function delegates to a library.

### DepositLib.sol

Validates the token is supported, pulls funds from the user via `transferFrom`, and emits `CryptoDeposited` for the Alchemy webhook to consume.

### WithdrawalLib.sol

Verifies the user's EIP-712 typed signature, increments the replay-prevention nonce, and transfers tokens to the treasury. Follows checks-effects-interactions strictly.

### TokenLib.sol

Manages the supported token allowlist. Supports adding, removing, and bulk-seeding tokens at deploy time.

### ConfigLib.sol

Manages the treasury address, per-transaction withdrawal cap, and contract balance queries.

---

## Security Properties

| Property          | Implementation                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| Replay protection | Per-user nonces incremented before external calls                                                 |
| Signature binding | EIP-712 binds user, token, amount, and nonce — no field substitution possible                     |
| Fund destination  | Withdrawals always go to `treasury`, never to `msg.sender`                                        |
| Role separation   | `DISPATCHER_ROLE` can only execute withdrawals; `DEFAULT_ADMIN_ROLE` controls config and upgrades |
| Upgrade safety    | ERC-7201 namespaced storage prevents slot collisions across upgrades                              |
| Pause mechanism   | `PAUSER_ROLE` can halt deposits and withdrawals independently of admin                            |
| CEI pattern       | State changes (nonce++) always precede external token transfers                                   |

---

## Roles

| Role                 | Holder              | Permissions                                                       |
| -------------------- | ------------------- | ----------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` | Multisig            | Upgrade contract, set treasury, set withdrawal cap, manage tokens |
| `PAUSER_ROLE`        | Admin or ops wallet | Pause and unpause the system                                      |
| `DISPATCHER_ROLE`    | NestJS hot wallet   | Call `processGaslessWithdrawal`                                   |

---

## Contract Interface

### User Functions

```solidity
/// Deposit supported ERC-20 tokens into the bridge.
/// Requires prior ERC-20 approve() for this contract.
function depositCrypto(address _token, uint256 _amount) external;
```

### Dispatcher Functions

```solidity
/// Execute a user-signed gasless withdrawal.
/// Transfers tokens to treasury and emits event for NestJS to trigger bank payout.
function processGaslessWithdrawal(
    address _user,
    address _token,
    uint256 _amount,
    bytes calldata _signature
) external;
```

### Admin Functions

```solidity
function pause() external;
function unpause() external;
function setTreasury(address _newTreasury) external;
function setMaxWithdrawalPerTx(uint256 _newMax) external;
function addSupportedToken(address _token) external;
function removeSupportedToken(address _token) external;
```

### View Functions

```solidity
function getUserNonce(address _user) external view returns (uint256);
function isTokenSupported(address _token) external view returns (bool);
function getContractBalance(address _token) external view returns (uint256);
function getTreasury() external view returns (address);
function getMaxWithdrawalPerTx() external view returns (uint256);
function getIsPaused() external view returns (bool);
```

---

## EIP-712 Signature

Users sign a typed `WithdrawRequest` off-chain (no gas). The dispatcher submits it on their behalf.

**Domain:**

```json
{
  "name": "DigitalNairaWallet",
  "version": "1",
  "chainId": <chainId>,
  "verifyingContract": "<contract_address>"
}
```

**Type:**

```json
{
  "WithdrawRequest": [
    { "name": "user", "type": "address" },
    { "name": "token", "type": "address" },
    { "name": "amount", "type": "uint256" },
    { "name": "nonce", "type": "uint256" }
  ]
}
```

**Frontend example (ethers.js):**

```typescript
const domain = {
  name: "DigitalNairaWallet",
  version: "1",
  chainId: await signer.getChainId(),
  verifyingContract: CONTRACT_ADDRESS,
};

const types = {
  WithdrawRequest: [
    { name: "user", type: "address" },
    { name: "token", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
};

const nonce = await contract.getUserNonce(userAddress);

const value = {
  user: userAddress,
  token: USDC_ADDRESS,
  amount: parseUnits("100", 6),
  nonce,
};

const signature = await signer.signTypedData(domain, types, value);
// Send { user, token, amount, signature } to your NestJS backend
```

---

## Events

| Event                                                 | Emitted By                 | NestJS Action                         |
| ----------------------------------------------------- | -------------------------- | ------------------------------------- |
| `CryptoDeposited(user, token, amount)`                | `depositCrypto`            | Credit user's Naira balance in Prisma |
| `FiatWithdrawalProcessed(user, token, amount, nonce)` | `processGaslessWithdrawal` | Confirm debit, trigger bank payout    |
| `TokenAdded(token)`                                   | `addSupportedToken`        | Update supported token list in DB     |
| `TokenRemoved(token)`                                 | `removeSupportedToken`     | Update supported token list in DB     |
| `TreasuryUpdated(old, new)`                           | `setTreasury`              | Audit log                             |
| `Paused(by)` / `Unpaused(by)`                         | `pause` / `unpause`        | Alert ops team                        |

---

## Deployment

### Prerequisites

```bash
npm install
# or
forge install
```

### Initialize Parameters

| Parameter             | Description                                                               |
| --------------------- | ------------------------------------------------------------------------- |
| `_admin`              | Multisig address — gets `DEFAULT_ADMIN_ROLE` and `PAUSER_ROLE`            |
| `_dispatcher`         | NestJS hot wallet — gets `DISPATCHER_ROLE`                                |
| `_treasury`           | Destination for withdrawn funds (use a Gnosis Safe)                       |
| `_initialTokens`      | Array of supported token addresses e.g. `[USDC, USDT]`                    |
| `_maxWithdrawalPerTx` | Per-tx cap in token decimals e.g. `1000000000` for 1000 USDC (6 decimals) |

### Deploy (Hardhat)

```typescript
const NairaBridgeManager =
  await ethers.getContractFactory("NairaBridgeManager");

const proxy = await upgrades.deployProxy(
  NairaBridgeManager,
  [
    ADMIN_ADDRESS,
    DISPATCHER_ADDRESS,
    TREASURY_ADDRESS,
    [USDC_ADDRESS, USDT_ADDRESS],
    parseUnits("1000", 6), // 1000 USDC max per tx
  ],
  { kind: "uups" },
);

await proxy.waitForDeployment();
console.log("Proxy deployed to:", await proxy.getAddress());
```

> ⚠️ **Before deploying:** verify the `STORAGE_LOCATION` constant matches the ERC-7201 formula:
>
> ```
> keccak256(abi.encode(uint256(keccak256("nairabridge.storage.main")) - 1)) & ~bytes32(uint256(0xff))
> ```

---

## Upgrading

Only `DEFAULT_ADMIN_ROLE` can authorise upgrades.

```typescript
const upgraded = await upgrades.upgradeProxy(
  PROXY_ADDRESS,
  NewImplementationFactory,
);
await upgraded.waitForDeployment();
```

When adding new storage fields in an upgrade, always append to the **end** of `BridgeStorage` — never insert or reorder existing fields.

---

## Custom Errors

| Error                                      | Thrown When                                        |
| ------------------------------------------ | -------------------------------------------------- |
| `ZeroAddress()`                            | An address parameter is `address(0)`               |
| `ZeroAmount()`                             | An amount parameter is `0`                         |
| `UnsupportedToken()`                       | Token is not on the allowlist                      |
| `TokenAlreadySupported()`                  | Token is already on the allowlist                  |
| `InvalidSignature()`                       | EIP-712 signature does not match `_user`           |
| `ExceedsMaxWithdrawal(requested, maximum)` | Amount exceeds per-tx cap                          |
| `TransferFailed()`                         | ERC-20 `transfer` or `transferFrom` returned false |
| `SystemPaused()`                           | Action attempted while contract is paused          |
| `SystemNotPaused()`                        | Unpause attempted while contract is not paused     |

**NestJS error handling example:**

```typescript
try {
  await contract.processGaslessWithdrawal(user, token, amount, signature);
} catch (err) {
  switch (err.errorName) {
    case "InvalidSignature":
      throw new UnauthorizedException("Invalid withdrawal signature");
    case "ExceedsMaxWithdrawal":
      throw new BadRequestException(
        `Amount exceeds maximum of ${formatUnits(err.errorArgs[1], 6)} USDC`,
      );
    case "UnsupportedToken":
      throw new BadRequestException("Token not supported");
    case "SystemPaused":
      throw new ServiceUnavailableException("Bridge is currently paused");
  }
}
```

---

## Dependencies

- [OpenZeppelin Contracts Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) `^5.x`
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) `^5.x`

---

## License

MIT
