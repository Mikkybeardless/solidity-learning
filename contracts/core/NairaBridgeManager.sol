// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import "../libraries/DepositLib.sol";
import "../libraries/WithdrawalLib.sol";
import "../libraries/TokenLib.sol";
import "../libraries/ConfigLib.sol";

/// @title  NairaBridgeManager
/// @notice Thin orchestrator. All business logic lives in the four libraries.
///         This contract owns storage, roles, upgradeability, and pause state —
///         nothing else.
/// @dev    UUPS-upgradeable, ERC-7201 namespaced storage.
contract NairaBridgeManager is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    EIP712Upgradeable
{
    // ROLES

    bytes32 public constant DISPATCHER_ROLE = keccak256("DISPATCHER_ROLE");
    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");

    // ERRORS

    error SystemPaused();
    error SystemNotPaused();

    // EVENTS

    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ERC-7201 NAMESPACED STORAGE
    //   slot = keccak256(abi.encode(uint256(keccak256("nairabridge.storage.main")) - 1))
    //          & ~bytes32(uint256(0xff))
    //
    // NOTE: The four sub-structs are laid out as consecutive fields inside
    // BridgeStorage so the assembly slot trick covers all of them under one
    // namespaced location. Each library receives only its own sub-struct by
    // reference — it cannot accidentally touch fields it doesn't own.

    struct BridgeStorage {
        // ConfigLib fields
        address treasury;
        uint256 maxWithdrawalPerTx;
        bool    isPaused;

        // TokenLib + DepositLib + WithdrawalLib share this mapping
        mapping(address => bool)    supportedTokens;

        // WithdrawalLib fields
        mapping(address => uint256) userNonces;
    }

// gotten from a generation function from remix
    bytes32 private constant STORAGE_LOCATION =
        0x3b5f9981132ad1a100682f6ebfd815f87ab231f8f89ab9a285cc1f567c892a00;

    function _getStorage() private pure returns (BridgeStorage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    // Each library gets a typed view into the shared storage.
    // Because Solidity storage references are pointers, writing through these
    // sub-struct views writes directly into BridgeStorage — no copying.

    function _depositStorage() private pure returns (DepositLib.DepositStorage storage $) {
        // supportedTokens is at the same slot as in BridgeStorage
        assembly { $.slot := STORAGE_LOCATION }
    }

    function _withdrawalStorage() private pure returns (WithdrawalLib.WithdrawalStorage storage $) {
        assembly { $.slot := STORAGE_LOCATION }
    }

    function _tokenStorage() private pure returns (TokenLib.TokenStorage storage $) {
        assembly { $.slot := STORAGE_LOCATION }
    }

    function _configStorage() private pure returns (ConfigLib.ConfigStorage storage $) {
        assembly { $.slot := STORAGE_LOCATION }
    }

    // INITIALIZER

    /// @param _admin              Granted DEFAULT_ADMIN_ROLE + PAUSER_ROLE.
    /// @param _dispatcher         NestJS hot-wallet; granted DISPATCHER_ROLE.
    /// @param _treasury           Destination for withdrawn funds (use a multisig).
    /// @param _initialTokens      Token addresses to whitelist at deploy time.
    /// @param _maxWithdrawalPerTx Hard cap per withdrawal call (token decimals).
    function initialize(
        address          _admin,
        address          _dispatcher,
        address          _treasury,
        address[] calldata _initialTokens,
        uint256          _maxWithdrawalPerTx
    ) public initializer {
        if (_admin      == address(0)) revert ConfigLib.ZeroAddress();
        if (_dispatcher == address(0)) revert ConfigLib.ZeroAddress();

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __EIP712_init("DigitalNairaWallet", "1");

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE,        _admin);
        _grantRole(DISPATCHER_ROLE,    _dispatcher);

        // Initialise config
        ConfigLib.ConfigStorage storage cfg = _configStorage();
        ConfigLib.setTreasury(cfg, _treasury);
        ConfigLib.setMaxWithdrawalPerTx(cfg, _maxWithdrawalPerTx);

        // Seed supported tokens
        TokenLib.seedTokens(_tokenStorage(), _initialTokens);

        _getStorage().isPaused = false;
    }

    // MODIFIERS
    modifier whenNotPaused() {
        if (_getStorage().isPaused) revert SystemPaused();
        _;
    }

    modifier whenPaused() {
        if (!_getStorage().isPaused) revert SystemNotPaused();
        _;
    }

    // 1. USER DEPOSIT  (Frontend → Contract)
    function depositCrypto(address _token, uint256 _amount) external whenNotPaused {
        DepositLib.deposit(_depositStorage(), _token, _amount);
    }

    // 2. GASLESS WITHDRAWAL  (Backend → Contract)
    function processGaslessWithdrawal(
        address _user,
        address _token,
        uint256 _amount,
        bytes calldata _signature
    ) external onlyRole(DISPATCHER_ROLE) whenNotPaused {
        WithdrawalLib.processWithdrawal(
            _withdrawalStorage(),
            _domainSeparatorV4(),   // EIP-712 domain separator from this contract
            _user,
            _token,
            _amount,
            _signature
        );
    }

    // ADMIN: PAUSE / UNPAUSE

    function pause() external onlyRole(PAUSER_ROLE) whenNotPaused {
        _getStorage().isPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(PAUSER_ROLE) whenPaused {
        _getStorage().isPaused = false;
        emit Unpaused(msg.sender);
    }

    // ADMIN: CONFIG SETTERS
    function setTreasury(address _newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ConfigLib.setTreasury(_configStorage(), _newTreasury);
    }

    function setMaxWithdrawalPerTx(uint256 _newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ConfigLib.setMaxWithdrawalPerTx(_configStorage(), _newMax);
    }

    // ADMIN: TOKEN MANAGEMENT

    function addSupportedToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TokenLib.addToken(_tokenStorage(), _token);
    }

    function removeSupportedToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TokenLib.removeToken(_tokenStorage(), _token);
    }

    // VIEW HELPERS  (for NestJS off-chain queries)
    function isTokenSupported(address _token) external view returns (bool) {
        return _getStorage().supportedTokens[_token];
    }

    function getUserNonce(address _user) external view returns (uint256) {
        return _getStorage().userNonces[_user];
    }

    function getIsPaused() external view returns (bool) {
        return _getStorage().isPaused;
    }

    function getTreasury() external view returns (address) {
        return _getStorage().treasury;
    }

    function getMaxWithdrawalPerTx() external view returns (uint256) {
        return _getStorage().maxWithdrawalPerTx;
    }

    function getContractBalance(address _token) external view returns (uint256) {
        return ConfigLib.getContractBalance(_token);
    }

    // UUPS UPGRADE AUTHORISATION

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
