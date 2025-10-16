// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DEPOSIT, DepositStateChange} from "../vault/OffchainAssetReceiptVault.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN
} from "./OffchainAssetReceiptVaultAuthorizerV1.sol";
import {LibFixedPointDecimalScale, FLAG_ROUND_UP} from "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import {VerifyStatus, IVerifyV1, VERIFY_STATUS_APPROVED} from "rain.verify.interface/interface/IVerifyV1.sol";

/// @dev Thrown when the OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
/// initialized with a zero address for the receipt vault.
error ZeroReceiptVault();

/// @dev Thrown when the OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
/// initialized with a zero address for the verify contract used to KYC the
/// owner of the payment token that is buying the tokens.
error ZeroVerifyContract();

/// @dev Thrown when the OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
/// initialized with a zero address for the owner.
error ZeroInitialOwner();

/// @dev Thrown when the OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
/// initialized with a zero address for the payment token.
error ZeroPaymentToken();

/// @dev Thrown when the OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
/// initialized with a zero max shares supply.
error ZeroMaxSharesSupply();

/// @dev Thrown when more than the maximum shares supply is minted.
/// @param maxSharesSupply The maximum shares supply allowed.
/// @param sharesMinted The total shares minted, including the current mint.
error MaxSharesSupplyExceeded(uint256 maxSharesSupply, uint256 sharesMinted);

/// @dev Thrown when the payment token decimals do not match the expected
/// value.
/// @param expected The expected payment token decimals.
/// @param actual The actual payment token decimals.
error PaymentTokenDecimalMismatch(uint256 expected, uint256 actual);

/// @dev Configuration for the OffchainAssetReceiptVaultPaymentMintAuthorizerV1
/// initialization.
/// @param receiptVault The address of the receipt vault.
/// @param verify The address of the verify contract used to KYC the owner of
/// the payment token that is buying the tokens.
/// @param owner The address of the initial owner. Will also be the initial admin
/// for role management.
/// @param paymentToken The address of the payment token used to pay for minting.
/// @param maxSharesSupply The maximum number of shares that can be minted in
/// total globally.
struct OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config {
    address receiptVault;
    address verify;
    address owner;
    address paymentToken;
    uint256 maxSharesSupply;
}

/// @title OffchainAssetReceiptVaultPaymentMintAuthorizerV1
/// @notice This contract is an authorizer for the OffchainAssetReceiptVault
/// that allows minting of shares in exchange for payment in a specified token.
///
/// It makes several critical security sensitive assumptions that rely on the
/// caller of the `authorize` function being the well known
/// `OffchainAssetReceiptVault` contract. For this reason, all calls to
/// `authorize` will revert as `Unauthorized` if the caller is not the receipt
/// vault address set at initialization.
///
/// This contract inherits from `OffchainAssetReceiptVaultAuthorizerV1` and so
/// implements all the same roles and associated access logic for those roles,
/// but removes the ability for DEPOSIT and WITHDRAW to ever be granted to
/// any address.
///
/// To successfully authorize a deposit, the owner of the deposit must pay tokens
/// 1:1 to this contract in exchange for shares minted. The 1:1 ratio is
/// calculated according to the payment token's decimals, against the shares
/// being 18 decimals. There are no restrictions on who can deposit, as long
/// as they pay the required amount of payment tokens.
///
/// Withdrawals are completely disabled. Instead there is a maximum number of
/// shares that can be minted in total, which is set at initialization.
///
/// At any time anon can call `sendPaymentToOwner` to transfer all the payment
/// tokens held by this contract to the owner of the authorizer.
contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is OffchainAssetReceiptVaultAuthorizerV1, Ownable {
    using SafeERC20 for IERC20;

    /// @dev The address of the receipt vault that this authorizer is for.
    /// Immutable after initialization.
    address internal sReceiptVault;
    /// @dev The address of the payment token that is used to pay for minting.
    /// Immutable after initialization.
    address internal sPaymentToken;
    /// @dev The decimals of the payment token that is used to pay for minting.
    /// Immutable after initialization.
    /// If the payment token contract ever reports a different decimals value
    /// than this value, the authorizer will revert all deposits.
    uint8 internal sPaymentTokenDecimals;
    /// @dev The maximum number of shares that can be minted in total globally.
    /// Immutable after initialization.
    uint256 internal sMaxSharesSupply;
    /// @dev The verify contract used to KYC the owner of the payment token that
    /// is buying the tokens.
    IVerifyV1 internal sVerify;

    /// @dev Emitted when the authorizer is initialized.
    /// @param receiptVault The address of the receipt vault.
    /// @param verify The address of the verify contract used to KYC the owner of
    /// the payment token that is buying the tokens.
    /// @param owner The address of the initial owner.
    /// @param paymentToken The address of the payment token used to pay for
    /// minting.
    /// @param paymentTokenDecimals The decimals of the payment token used to
    /// pay for minting.
    /// @param maxSharesSupply The maximum number of shares that can be minted
    /// in total globally.
    event Initialized(
        address receiptVault,
        address verify,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply
    );

    /// Constructor is used to disable initializers in the base contract
    /// so that this contract can only be initialized through the `initialize`
    /// function. Standard approach to cloneable contracts compatible with the
    /// Rain clone factory.
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config memory config =
            abi.decode(data, (OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config));

        if (config.receiptVault == address(0)) {
            revert ZeroReceiptVault();
        }

        if (config.verify == address(0)) {
            revert ZeroVerifyContract();
        }

        if (config.owner == address(0)) {
            revert ZeroInitialOwner();
        }

        if (config.paymentToken == address(0)) {
            revert ZeroPaymentToken();
        }

        if (config.maxSharesSupply == 0) {
            revert ZeroMaxSharesSupply();
        }

        sReceiptVault = config.receiptVault;
        sVerify = IVerifyV1(config.verify);
        sPaymentToken = config.paymentToken;
        // TOFU pattern to snapshot token decimals at initialization, then
        // enforce they are always the same for all deposits.
        uint8 lPaymentTokenDecimals = IERC20Metadata(config.paymentToken).decimals();
        sPaymentTokenDecimals = lPaymentTokenDecimals;
        sMaxSharesSupply = config.maxSharesSupply;

        __Ownable_init();

        emit Initialized(
            config.receiptVault,
            config.verify,
            config.owner,
            config.paymentToken,
            lPaymentTokenDecimals,
            config.maxSharesSupply
        );

        // Owner of the authorizer is also the initial admin for role management.
        _transferOwnership(config.owner);
        super._initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: config.owner})));

        // By revoking the deposit and withdraw admin roles we ensure that there
        // can never be any addresses with deposit or withdraw roles. This
        // simplifies the logic of overriding the inherited authorize function
        // by allowing all the default deposit/withdraw logic to exist knowing
        // it will never execute.
        _revokeRole(DEPOSIT_ADMIN, config.owner);
        _revokeRole(WITHDRAW_ADMIN, config.owner);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes memory data) public virtual override {
        address lReceiptVault = sReceiptVault;
        // Ensure that the caller is the receipt vault to prevent any possible
        // malicious calls from untrusted sources.
        if (msg.sender != lReceiptVault) {
            revert Unauthorized(user, permission, data);
        }
        if (permission == DEPOSIT) {
            DepositStateChange memory stateChange = abi.decode(data, (DepositStateChange));
            address lPaymentToken = sPaymentToken;
            uint256 lPaymentTokenDecimals = sPaymentTokenDecimals;
            uint256 paymentAmount =
                LibFixedPointDecimalScale.scaleN(stateChange.sharesMinted, lPaymentTokenDecimals, FLAG_ROUND_UP);

            // Enforce TOFU use of payment token decimals value.
            uint256 currentPaymentTokenDecimals = IERC20Metadata(lPaymentToken).decimals();
            if (currentPaymentTokenDecimals != lPaymentTokenDecimals) {
                revert PaymentTokenDecimalMismatch(lPaymentTokenDecimals, currentPaymentTokenDecimals);
            }

            // Authorization happens after deposit so supply includes the newly
            // minted shares.
            uint256 newSharesSupply = IERC20(lReceiptVault).totalSupply();
            if (newSharesSupply > sMaxSharesSupply) {
                revert MaxSharesSupplyExceeded(sMaxSharesSupply, newSharesSupply);
            }

            // We check the payment amount being non-zero rather than the shares
            // amount to ensure that it is never possible that somehow some bad
            // rounding introduces the possibility of minting some amount of
            // shares for free. That shouldn't happen because we round up, but
            // this is safer anyway.
            if (paymentAmount == 0) {
                revert Unauthorized(stateChange.owner, DEPOSIT, data);
            }

            // This is a false positive for slither because the offchain asset
            // receipt vault sets `stateChange.owner` to `msg.sender` from its
            // perspective, which is the main thing slither wants, to avoid users
            // being able to consume approvals from other unrelated users.
            // This contract is NOT compatible with arbitrary callers, it is ONLY
            // compatible with the well known offchain asset receipt vault.
            //slither-disable-next-line arbitrary-send-erc20
            IERC20(lPaymentToken).safeTransferFrom(stateChange.owner, address(this), paymentAmount);

            // KYC the owner of the payment token that is buying the tokens. We
            // do this rather than KYC on the receiver of the minted shares as
            // there is no KYC on transfers, there's nothing stopping the owner
            // from minting to themselves then transferring the shares to an
            // arbitrary address.
            VerifyStatus verifyStatus = sVerify.accountStatusAtTime(stateChange.owner, block.timestamp);
            if (VerifyStatus.unwrap(verifyStatus) != VerifyStatus.unwrap(VERIFY_STATUS_APPROVED)) {
                revert Unauthorized(stateChange.owner, DEPOSIT, data);
            }

            return;
        } else {
            // Fallback to the inherited authorize function for all other
            // permissions.
            super.authorize(user, permission, data);
        }
    }

    /// Anon can call this function at any time to transfer all the payment
    /// tokens held by this contract to the owner of the authorizer.
    function sendPaymentToOwner() external {
        IERC20(sPaymentToken).safeTransfer(owner(), IERC20(sPaymentToken).balanceOf(address(this)));
    }

    /// Returns the address of the receipt vault that this authorizer is for.
    function receiptVault() external view returns (address) {
        return sReceiptVault;
    }

    /// Returns the address of the payment token that is used to pay for minting.
    function paymentToken() external view returns (address) {
        return sPaymentToken;
    }

    /// Returns the decimals of the payment token that is used to pay for minting.
    function paymentTokenDecimals() external view returns (uint8) {
        return sPaymentTokenDecimals;
    }

    /// Returns the maximum number of shares that can be minted in total.
    function maxSharesSupply() external view returns (uint256) {
        return sMaxSharesSupply;
    }
}
