// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";
import {IERC165Upgradeable as IERC165} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DEPOSIT, DepositStateChange} from "../vault/OffchainAssetReceiptVault.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

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

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
    IAuthorizeV1,
    ICloneableV2,
    IERC165,
    Initializable,
    Ownable
{
    using SafeERC20 for IERC20;

    address internal sReceiptVault;
    address internal sPaymentToken;
    uint256 internal sPaymentTokenDecimals;
    uint256 internal sMaxSharesSupply;

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
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
        uint256 paymentTokenDecimals = IERC20Metadata(config.paymentToken).decimals();
        sPaymentTokenDecimals = paymentTokenDecimals;
        sMaxSharesSupply = config.maxSharesSupply;

        _transferOwnership(config.owner);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(ICloneableV2).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes calldata data) external virtual override {
        address receiptVault = sReceiptVault;
        // Ensure that the caller is the receipt vault to prevent any possible
        // malicious calls from untrusted sources.
        if (msg.sender != receiptVault) {
            revert Unauthorized(user, permission, data);
        }

        if (permission == DEPOSIT) {
            DepositStateChange memory stateChange = abi.decode(data, (DepositStateChange));
            address paymentToken = sPaymentToken;
            uint256 paymentTokenDecimals = sPaymentTokenDecimals;
            uint256 paymentAmount =
                LibFixedPointDecimalScale.scaleN(stateChange.sharesMinted, paymentTokenDecimals, FLAG_ROUND_UP);

            // Enforce TOFU use of payment token decimals value.
            uint256 currentPaymentTokenDecimals = IERC20Metadata(paymentToken).decimals();
            if (currentPaymentTokenDecimals != paymentTokenDecimals) {
                revert PaymentTokenDecimalMismatch(paymentTokenDecimals, currentPaymentTokenDecimals);
            }

            uint256 oldSharesSupply = IERC20(receiptVault).totalSupply();
            uint256 newSharesSupply = oldSharesSupply + stateChange.sharesMinted;
            if (newSharesSupply > sMaxSharesSupply) {
                revert MaxSharesSupplyExceeded(sMaxSharesSupply, newSharesSupply);
            }

            IERC20(paymentToken).safeTransferFrom(stateChange.owner, address(this), paymentAmount);
        }
    }

    function sendPaymentToOwner() external {
        IERC20(sPaymentToken).safeTransfer(owner(), IERC20(sPaymentToken).balanceOf(address(this)));
    }
}
