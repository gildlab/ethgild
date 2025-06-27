// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";
import {ERC165Upgradeable as ERC165} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DEPOSIT, WITHDRAW, DepositStateChange} from "../vault/OffchainAssetReceiptVault.sol";
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

error ZeroReceiptVault();

error ZeroInitialOwner();

error ZeroPaymentToken();

error ZeroMaxSharesSupply();

error MaxSharesSupplyExceeded(uint256 maxSharesSupply, uint256 sharesMinted);

error PaymentTokenDecimalMismatch(uint256 expected, uint256 actual);

struct OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config {
    address receiptVault;
    address owner;
    address paymentToken;
    uint256 maxSharesSupply;
}

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is OffchainAssetReceiptVaultAuthorizerV1, Ownable {
    using SafeERC20 for IERC20;

    address internal sReceiptVault;
    address internal sPaymentToken;
    uint8 internal sPaymentTokenDecimals;
    uint256 internal sMaxSharesSupply;

    event Initialized(
        address receiptVault, address owner, address paymentToken, uint8 paymentTokenDecimals, uint256 maxSharesSupply
    );

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
        sPaymentToken = config.paymentToken;
        uint8 lPaymentTokenDecimals = IERC20Metadata(config.paymentToken).decimals();
        sPaymentTokenDecimals = lPaymentTokenDecimals;
        sMaxSharesSupply = config.maxSharesSupply;

        __Ownable_init();

        emit Initialized(
            config.receiptVault, config.owner, config.paymentToken, lPaymentTokenDecimals, config.maxSharesSupply
        );

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

            uint256 oldSharesSupply = IERC20(lReceiptVault).totalSupply();
            uint256 newSharesSupply = oldSharesSupply + stateChange.sharesMinted;
            if (newSharesSupply > sMaxSharesSupply) {
                revert MaxSharesSupplyExceeded(sMaxSharesSupply, newSharesSupply);
            }

            IERC20(lPaymentToken).safeTransferFrom(stateChange.owner, address(this), paymentAmount);

            return;
        } else {
            super.authorize(user, permission, data);
        }
    }

    function sendPaymentToOwner() external {
        IERC20(sPaymentToken).safeTransfer(owner(), IERC20(sPaymentToken).balanceOf(address(this)));
    }

    function receiptVault() external view returns (address) {
        return sReceiptVault;
    }

    function paymentToken() external view returns (address) {
        return sPaymentToken;
    }

    function paymentTokenDecimals() external view returns (uint8) {
        return sPaymentTokenDecimals;
    }

    function maxSharesSupply() external view returns (uint256) {
        return sMaxSharesSupply;
    }
}
