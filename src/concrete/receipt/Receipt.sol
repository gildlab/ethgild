// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

import {IReceiptManagerV1} from "../../interface/IReceiptManagerV1.sol";
import {IReceiptV2} from "../../interface/IReceiptV2.sol";
import {IReceiptVaultV1} from "../../interface/IReceiptVaultV1.sol";
import {OnlyManager, ZeroReceiptId} from "../../error/ErrReceipt.sol";
import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {Base64Upgradeable as Base64} from "openzeppelin-contracts-upgradeable/contracts/utils/Base64Upgradeable.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";

/// @dev The prefix for data URIs as base64 encoded JSON.
string constant DATA_URI_BASE64_PREFIX = "data:application/json;base64,";

/// @dev The name of a `Receipt` is "<vault share symbol> Receipt".
string constant RECEIPT_NAME_SUFFIX = " Receipt";

/// @dev The symbol of a `Receipt` is "<vault share symbol> RCPT".
string constant RECEIPT_SYMBOL_SUFFIX = " RCPT";

/// @dev The default symbol for the reference asset.
string constant DEFAULT_REFERENCE_ASSET_SYMBOL = "USD";

/// @dev The default URL for redeeming receipts.
string constant DEFAULT_REDEEM_URL = "";

/// @dev The default brand name for the receipt.
string constant DEFAULT_BRAND_NAME = "";

/// @dev The default SVG URI for the receipt.
string constant DEFAULT_SVG_URI = "";

/// @title Receipt
/// @notice The `IReceiptV2` for a `ReceiptVault`. Standard implementation allows
/// receipt information to be emitted and mints/burns according to manager
/// authorization.
contract Receipt is IReceiptV2, ERC1155, ICloneableV2 {
    /// The manager of the `Receipt` contract.
    /// Set during `initialize` and cannot be changed.
    /// Intended to be a `ReceiptVault` contract.
    IReceiptManagerV1 internal sManager;

    /// Disables initializers so that the clonable implementation cannot be
    /// initialized and used directly outside a factory deployment.
    constructor() {
        _disableInitializers();
    }

    /// Throws if the caller is not the manager of the `Receipt` contract.
    modifier onlyManager() {
        if (msg.sender != address(sManager)) {
            revert OnlyManager();
        }
        _;
    }

    /// Initializes the `Receipt` so that it is usable as a clonable
    /// implementation in `ReceiptFactory`.
    /// Compatible with `ICloneableV2`.
    function initialize(bytes memory data) external override initializer returns (bytes32) {
        __ERC1155_init("");

        address receiptManager = abi.decode(data, (address));
        sManager = IReceiptManagerV1(receiptManager);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc ERC1155
    function uri(uint256 id) public view virtual override returns (string memory) {
        if (id == 0) {
            revert ZeroReceiptId();
        }
        string memory redeemURL = _redeemURL();
        string memory redeemURLPhrase = bytes(redeemURL).length > 0 ? string.concat(" Redeem at ", redeemURL, ".") : "";

        string memory brandName = _brandName();
        string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";

        string memory receiptSVGURI = _receiptSVGURI();
        string memory receiptSVGURIPhrase =
            bytes(receiptSVGURI).length > 0 ? string.concat("\"image\":\"", receiptSVGURI, "\",") : "";

        bytes memory json = bytes(
            string.concat(
                "{\"decimals\":18,\"description\":\"1 of these receipts can be burned alongside 1 ",
                _vaultShareSymbol(),
                " to redeem ",
                LibFixedPointDecimalFormat.fixedPointToDecimalString(
                    LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
                ),
                " of ",
                _vaultAssetSymbol(),
                ".",
                redeemURLPhrase,
                "\",",
                receiptSVGURIPhrase,
                "\"name\":\"Receipt for ",
                brandNamePhrase,
                "lock at ",
                LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
                " ",
                _referenceAssetSymbol(),
                " per ",
                _vaultAssetSymbol(),
                ".\"}"
            )
        );

        return string.concat(DATA_URI_BASE64_PREFIX, Base64.encode(json));
    }

    /// @inheritdoc IReceiptV2
    function name() external view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_NAME_SUFFIX);
    }

    /// @inheritdoc IReceiptV2
    function symbol() external view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_SYMBOL_SUFFIX);
    }

    /// @inheritdoc IReceiptV2
    function manager() external view virtual returns (address) {
        return address(sManager);
    }

    /// @inheritdoc IReceiptV2
    function managerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _receiptInformation(sender, id, data);
        _mint(account, id, amount, data);
    }

    /// @inheritdoc IReceiptV2
    function managerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _receiptInformation(sender, id, data);
        _burn(account, id, amount);
    }

    /// @inheritdoc IReceiptV2
    function managerTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _safeTransferFrom(from, to, id, amount, data);
    }

    function _vaultShareSymbol() internal view virtual returns (string memory) {
        return IERC20Metadata(payable(address(sManager))).symbol();
    }

    function _vaultAssetSymbol() internal view virtual returns (string memory) {
        return IERC20Metadata(IReceiptVaultV1(payable(address(sManager))).asset()).symbol();
    }

    function _receiptSVGURI() internal view virtual returns (string memory) {
        return DEFAULT_SVG_URI;
    }

    function _referenceAssetSymbol() internal view virtual returns (string memory) {
        return DEFAULT_REFERENCE_ASSET_SYMBOL;
    }

    function _redeemURL() internal view virtual returns (string memory) {
        return DEFAULT_REDEEM_URL;
    }

    function _brandName() internal view virtual returns (string memory) {
        return DEFAULT_BRAND_NAME;
    }

    /// Checks with the manager before authorizing transfer IN ADDITION to
    /// `super` inherited checks.
    /// @inheritdoc ERC1155
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        sManager.authorizeReceiptTransfer2(from, to);
    }

    /// Emits `ReceiptInformation` if there is any data after checking with the
    /// receipt manager for authorization.
    /// @param account The account that is emitting receipt information.
    /// @param id The id of the receipt this information is for.
    /// @param data The data being emitted as information for the receipt.
    function _receiptInformation(address account, uint256 id, bytes memory data) internal virtual {
        // No data is noop.
        if (data.length > 0) {
            emit ReceiptInformation(account, id, data);
        }
    }

    /// @inheritdoc IReceiptV2
    function receiptInformation(uint256 id, bytes memory data) external virtual {
        _receiptInformation(msg.sender, id, data);
    }
}
