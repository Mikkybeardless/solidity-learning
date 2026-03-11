// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./BridgeErrors.sol";

/// @title  WithdrawalLib
/// @notice Handles the processGaslessWithdrawal logic for NairaBridgeManager.
/// @dev    Verifies EIP-712 signatures, manages nonces, and transfers tokens
///         to the treasury. The EIP-712 domain separator is passed in from the
///         main contract since EIP712Upgradeable lives there.
library WithdrawalLib {

    // EVENTS
    event FiatWithdrawalProcessed(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 nonce
    );

    // CONSTANTS
    /// @dev Must match the struct used when the user signs on the frontend.
    bytes32 internal constant WITHDRAW_TYPEHASH =
        keccak256("WithdrawRequest(address user,address token,uint256 amount,uint256 nonce)");

    // STORAGE INTERFACE
    // Only the fields this library actually touches.
    struct WithdrawalStorage {
        address treasury;
        uint256 maxWithdrawalPerTx;
        mapping(address => bool)    supportedTokens;
        mapping(address => uint256) userNonces;
    }

    // LOGIC

    /// @notice Execute a user-authorised gasless withdrawal.
    /// @param  self            The slice of storage this library cares about.
    /// @param  _domainSeparator EIP-712 domain separator from the main contract.
    /// @param  _user           End-user whose funds are being redeemed.
    /// @param  _token          ERC-20 token to transfer (must be supported).
    /// @param  _amount         Amount to transfer to treasury.
    /// @param  _signature      EIP-712 signature produced by `_user`'s wallet.
    function processWithdrawal(
        WithdrawalStorage storage self,
        bytes32 _domainSeparator,
        address _user,
        address _token,
        uint256 _amount,
        bytes calldata _signature
    ) internal {
        if (_user   == address(0)) revert BridgeErrors.ZeroAddress();
        if (_amount == 0)          revert BridgeErrors.ZeroAmount();
        if (!self.supportedTokens[_token]) revert BridgeErrors.UnsupportedToken();
        if (_amount > self.maxWithdrawalPerTx)
        revert BridgeErrors.ExceedsMaxWithdrawal(_amount, self.maxWithdrawalPerTx);

        // --- EIP-712 signature verification ---
        uint256 currentNonce = self.userNonces[_user];

        bytes32 structHash = keccak256(
            abi.encode(WITHDRAW_TYPEHASH, _user, _token, _amount, currentNonce)
        );

        // Reconstruct the typed data hash using the domain separator passed in
        bytes32 hash   = ECDSA.toTypedDataHash(_domainSeparator, structHash);
        address signer = ECDSA.recover(hash, _signature);
        if (signer != _user) revert BridgeErrors.InvalidSignature();

        // Increment nonce BEFORE external call (checks-effects-interactions)
        self.userNonces[_user]++;

        // Transfer to treasury
        bool ok = IERC20(_token).transfer(self.treasury, _amount);
        if (!ok) revert BridgeErrors.TransferFailed();

        emit FiatWithdrawalProcessed(_user, _token, _amount, currentNonce);
    }
}
