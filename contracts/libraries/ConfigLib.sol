// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "./BridgeErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  ConfigLib
/// @notice Manages treasury address and per-tx withdrawal cap for NairaBridgeManager.
library ConfigLib {

    // EVENTS
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MaxWithdrawalUpdated(uint256 oldMax, uint256 newMax);

    // STORAGE INTERFACE 
    struct ConfigStorage {
        address treasury;
        uint256 maxWithdrawalPerTx;
    }

    // LOGIC

    /// @notice Update the treasury address.
    function setTreasury(ConfigStorage storage self, address _newTreasury) internal {
        if (_newTreasury == address(0)) revert BridgeErrors.ZeroAddress();
        emit TreasuryUpdated(self.treasury, _newTreasury);
        self.treasury = _newTreasury;
    }

    /// @notice Update the per-transaction withdrawal cap.
    function setMaxWithdrawalPerTx(ConfigStorage storage self, uint256 _newMax) internal {
        if (_newMax == 0) revert BridgeErrors.ZeroAmount();
        emit MaxWithdrawalUpdated(self.maxWithdrawalPerTx, _newMax);
        self.maxWithdrawalPerTx = _newMax;
    }

    /// @notice Returns the balance of `_token` held by this contract.
    function getContractBalance(address _token) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
