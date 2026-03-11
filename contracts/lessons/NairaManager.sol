// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NairaBridgeManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable, EIP712Upgradeable {
    
    // --- ROLES & CONSTANTS ---
    bytes32 public constant DISPATCHER_ROLE = keccak256("DISPATCHER_ROLE");
    bytes32 private constant WITHDRAW_TYPEHASH = keccak256("WithdrawRequest(address user,uint256 amount,uint256 nonce)");

    // --- EVENTS (For Alchemy Webhooks) ---
    event CryptoDeposited(address indexed user, uint256 amount);
    event FiatWithdrawalProcessed(address indexed user, uint256 cryptoAmountBurnt, uint256 nonce);

    // --- ERC-7201 NAMESPACED STORAGE ---
    struct BridgeStorage {
        IERC20 stablecoin;
        mapping(address => uint256) userNonces;
        bool isPaused;
    }

    bytes32 private constant STORAGE_LOCATION = 0x3b5f9981132ad1a100682f6ebfd815f87ab231f8f89ab9a285cc1f567c892a00;

    function _getStorage() private pure returns (BridgeStorage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    // --- INITIALIZATION (No Constructor) ---
    function initialize(address _admin, address _dispatcher, address _stablecoin) public initializer {
        __AccessControl_init();
        // __UUPSUpgradeable_init();
        __EIP712_init("DigitalNairaWallet", "1");

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DISPATCHER_ROLE, _dispatcher); // This is your NestJS wallet address

        BridgeStorage storage $ = _getStorage();
        $.stablecoin = IERC20(_stablecoin);
        $.isPaused = false;
    }

    // --- 1. THE USER DEPOSIT (Frontend to Contract) ---
    function depositCrypto(uint256 _amount) external {
        BridgeStorage storage $ = _getStorage();
        require(!$.isPaused, "System paused");
        
        // Pull funds from user (Requires prior ERC-20 Approval or EIP-2612 Permit)
        require($.stablecoin.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // This event triggers the Alchemy Webhook -> NestJS -> Prisma User Balance Update
        emit CryptoDeposited(msg.sender, _amount);
    }

    // --- 2. THE WITHDRAWAL EXECUTION (Backend to Contract) ---
    function processGaslessWithdrawal(
        address _user, 
        uint256 _amount, 
        bytes calldata _signature
    ) external onlyRole(DISPATCHER_ROLE) {
        BridgeStorage storage $ = _getStorage();
        require(!$.isPaused, "System paused");

        uint256 currentNonce = $.userNonces[_user];

        // Verify the EIP-712 Signature
        bytes32 structHash = keccak256(abi.encode(WITHDRAW_TYPEHASH, _user, _amount, currentNonce));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, _signature);
        
        require(signer == _user, "Invalid EIP-712 Signature");

        // Increment nonce to prevent replay attacks
        $.userNonces[_user]++;

        // Transfer the crypto to the central treasury/liquidity pool
        require($.stablecoin.transfer(msg.sender, _amount), "Treasury transfer failed");

        // This event confirms on-chain execution so NestJS can safely trigger the Naira bank payout
        emit FiatWithdrawalProcessed(_user, _amount, currentNonce);
    }

    // --- UPGRADE AUTHORIZATION ---
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}