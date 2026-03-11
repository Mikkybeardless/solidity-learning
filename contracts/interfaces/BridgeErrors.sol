
library BridgeErrors {
    error ZeroAddress();
    error ZeroAmount();
    error SystemPaused();
    error SystemNotPaused();
    error InvalidSignature();
    error TransferFailed();
    error UnsupportedToken();
    error TokenAlreadySupported();
    error ExceedsMaxWithdrawal(uint256 requested, uint256 maximum);
}