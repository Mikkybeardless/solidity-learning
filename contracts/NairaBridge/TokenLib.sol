// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./BridgeErrors.sol";

/// @title  TokenLib
/// @notice Manages the supported token allowlist for NairaBridgeManager.
library TokenLib {



    // EVENTS

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    // STORAGE INTERFACE

    struct TokenStorage {
        mapping(address => bool) supportedTokens;
    }

    // LOGIC

    /// @notice Add a token to the supported list.
    function addToken(TokenStorage storage self, address _token) internal {
        if (_token == address(0)) revert BridgeErrors.ZeroAddress();
        if (self.supportedTokens[_token]) revert BridgeErrors.TokenAlreadySupported();
        self.supportedTokens[_token] = true;
        emit TokenAdded(_token);
    }

    /// @notice Remove a token from the supported list.
    function removeToken(TokenStorage storage self, address _token) internal {
        if (!self.supportedTokens[_token]) revert BridgeErrors.UnsupportedToken();
        self.supportedTokens[_token] = false;
        emit TokenRemoved(_token);
    }

    /// @notice Seed multiple tokens at once (used in initializer).
    function seedTokens(TokenStorage storage self, address[] calldata _tokens) internal {
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) revert BridgeErrors.ZeroAddress();
            self.supportedTokens[_tokens[i]] = true;
            emit TokenAdded(_tokens[i]);
        }
    }

    /// @notice Check whether a token is supported.
    function isSupported(TokenStorage storage self, address _token) internal view returns (bool) {
        return self.supportedTokens[_token];
    }
}
