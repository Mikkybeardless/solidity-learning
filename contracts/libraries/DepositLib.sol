// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BridgeErrors.sol";

/// @title  DepositLib
/// @notice Handles the depositCrypto logic for NairaBridgeManager.
/// @dev    Receives the BridgeStorage struct by reference and only reads
///         `supportedTokens`. Token transfer is executed directly via IERC20.
library DepositLib {



    // EVENTS
    event CryptoDeposited(address indexed user, address indexed token, uint256 amount);

    // STORAGE INTERFACE
    // Only the fields this library actually touches.
    struct DepositStorage {
        mapping(address => bool) supportedTokens;
    }

    // LOGIC
    /// @notice Pull `_amount` of `_token` from `msg.sender` into the bridge.
    /// @param  self     The slice of storage this library cares about.
    /// @param  _token   ERC-20 token address (must be supported).
    /// @param  _amount  Amount to deposit (must be > 0).
    function deposit(
        DepositStorage storage self,
        address _token,
        uint256 _amount
    ) internal {
        if (_amount == 0) revert BridgeErrors.ZeroAmount();
        if (!self.supportedTokens[_token]) revert BridgeErrors.UnsupportedToken();

        bool ok = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!ok) revert TransferFailed();

        emit CryptoDeposited(msg.sender, _token, _amount);
    }
}
