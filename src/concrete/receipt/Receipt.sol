// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

import {IReceiptManagerV2} from "../../interface/IReceiptManagerV2.sol";
import {IReceiptV3} from "../../interface/IReceiptV3.sol";
import {IReceiptVaultV3} from "../../interface/IReceiptVaultV3.sol";
import {OnlyManager} from "../../error/ErrReceipt.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @dev The prefix for data URIs as base64 encoded JSON.
string constant DATA_URI_BASE64_PREFIX = "data:application/json;base64,";

/// @dev The name of a `Receipt` is "<vault share symbol> Receipt".
string constant RECEIPT_NAME_SUFFIX = " Receipt";

/// @dev The symbol of a `Receipt` is "<vault share symbol> RCPT".
string constant RECEIPT_SYMBOL_SUFFIX = " RCPT";

/// @title Receipt
/// @notice The `IReceiptV3` for a `ReceiptVault`. Standard implementation allows
/// receipt information to be emitted and mints/burns according to manager
/// authorization.
contract Receipt is IReceiptV3, ICloneableV2, ERC1155Upgradeable {
    /// The manager of the `Receipt` contract.
    /// Set during `initialize` and cannot be changed.
    /// Intended to be a `ReceiptVault` contract.
    IReceiptManagerV2 internal sManager;

    address private sSender = address(0);

    /// Disables initializers so that the clonable implementation cannot be
    /// initialized and used directly outside a factory deployment.
    constructor() {
        _disableInitializers();
    }

    /// Throws if the caller is not the manager of the `Receipt` contract.
    modifier onlyManager() {
        _onlyManager();
        _;
    }
    /// Throws if the caller is not the manager of the `Receipt` contract.
    /// Dedicated function to avoid code bloat from using a modifier directly.

    function _onlyManager() internal view {
        if (_msgSender() != address(sManager)) {
            revert OnlyManager();
        }
    }

    /// Sets the sender for the duration of the function call. Requires that
    /// `_msgSender()` is used consistently instead of `msg.sender` so that the
    /// sender that is set here is actually used.
    /// @param sender The address to set as the sender.
    modifier withSender(address sender) {
        _withSenderBefore(sender);
        _;
        _withSenderAfter();
    }

    /// Sets the sender to `sender`. Dedicated function to avoid code bloat from
    /// using a modifier directly.
    /// @param sender The address to set as the sender.
    function _withSenderBefore(address sender) internal {
        sSender = sender;
    }
    /// Resets the sender to address(0). Dedicated function to avoid code bloat
    /// from using a modifier directly.

    function _withSenderAfter() internal {
        sSender = address(0);
    }

    /// Overrides `_msgSender` to allow `withSender` modifier to set the sender.
    function _msgSender() internal view virtual override returns (address) {
        address sender = sSender;
        return sender == address(0) ? msg.sender : sender;
    }

    /// Initializes the `Receipt` so that it is usable as a clonable
    /// implementation in `ReceiptFactory`.
    /// Compatible with `ICloneableV2`.
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        // `uri` is overridden in this contract so we can just initialize
        // `ERC1155` with an empty string.
        __ERC1155_init("");

        address receiptManager = abi.decode(data, (address));
        sManager = IReceiptManagerV2(receiptManager);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc ERC1155Upgradeable
    function uri(uint256) public view virtual override returns (string memory) {
        bytes memory json = bytes(
            string.concat(
                "{\"decimals\":",
                Strings.toString(_vaultDecimals()),
                ",\"description\":\"1 of these receipts can be burned alongside 1 ",
                _vaultShareSymbol(),
                " to redeem ",
                _vaultAssetSymbol(),
                " from the vault.\",",
                "\"name\":\"",
                name(),
                "\"}"
            )
        );

        return string.concat(DATA_URI_BASE64_PREFIX, Base64.encode(json));
    }

    /// @inheritdoc IReceiptV3
    function name() public view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_NAME_SUFFIX);
    }

    /// @inheritdoc IReceiptV3
    function symbol() external view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_SYMBOL_SUFFIX);
    }

    /// Provides the symbol of the `ReceiptVault` ERC20 share token that manages
    /// this `Receipt`. Can be overridden if the manager is not going to be
    /// a `ReceiptVault`.
    function _vaultShareSymbol() internal view virtual returns (string memory) {
        return IERC20Metadata(payable(address(sManager))).symbol();
    }

    /// Provides the symbol of the ERC20 asset token that the `ReceiptVault`
    /// managing this `Receipt` is accepting for mints. Can be overridden if the
    /// manager is not going to be a `ReceiptVault`.
    function _vaultAssetSymbol() internal view virtual returns (string memory) {
        return IERC20Metadata(IReceiptVaultV3(payable(address(sManager))).asset()).symbol();
    }

    //slither-disable-next-line dead-code
    function _vaultDecimals() internal view virtual returns (uint8) {
        return IERC20Metadata(payable(address(sManager))).decimals();
    }

    /// @inheritdoc IReceiptV3
    function manager() external view virtual returns (address) {
        return address(sManager);
    }

    /// @inheritdoc IReceiptV3
    function managerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
        withSender(sender)
    {
        _receiptInformation(sender, id, data);
        _mint(account, id, amount, data);
    }

    /// @inheritdoc IReceiptV3
    function managerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
        withSender(sender)
    {
        _receiptInformation(sender, id, data);
        _burn(account, id, amount);
    }

    /// @inheritdoc IReceiptV3
    function managerTransferFrom(
        address sender,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external virtual onlyManager withSender(sender) {
        _safeTransferFrom(from, to, id, amount, data);
    }

    /// Checks with the manager before authorizing transfer IN ADDITION to
    /// `super` inherited checks.
    /// @inheritdoc ERC1155Upgradeable
    function _update(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
        override
    {
        // _msgSender = operator in OZ 5.
        sManager.authorizeReceiptTransfer3(_msgSender(), from, to, ids, amounts);
        super._update(from, to, ids, amounts);
    }

    /// Emits `ReceiptInformation` if there is any data.
    /// @param account The account that is emitting receipt information.
    /// @param id The id of the receipt this information is for.
    /// @param data The data being emitted as information for the receipt.
    function _receiptInformation(address account, uint256 id, bytes memory data) internal virtual {
        // No data is noop.
        if (data.length > 0) {
            emit ReceiptInformation(account, id, data);
        }
    }

    /// @inheritdoc IReceiptV3
    function receiptInformation(uint256 id, bytes memory data) external virtual {
        _receiptInformation(_msgSender(), id, data);
    }
}
