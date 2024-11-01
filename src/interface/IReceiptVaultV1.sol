// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.0;

/// @title IReceiptVaultV1
/// @notice An ERC4626-like interface for a vault that issues ERC1155 receipts
/// alongside the ERC20 share tokens that it mints. The similarity to ERC4626
/// should make it familiar to auditors and implementors alike.
/// There are some key differences to ERC4626:
/// - ERC20 share mint/burn functions are all done within the context of a
///   specific ERC1155 receipt ID.
/// - Minting functions are all payable and NOT view, including previews, as they
///   MAY rely on paid external state such as oracles.
interface IReceiptVaultV1 {
    /// Similar to receipt information but for the entire vault. Anyone can emit
    /// any data about the vault, it is up to indexers to filter and clients to
    /// interpret the data.
    /// @param sender Sender of the receipt vault information.
    /// @param vaultInformation The vault information.
    event ReceiptVaultInformation(address sender, bytes vaultInformation);

    /// Similar to IERC4626 deposit but with receipt ID and information.
    /// @param sender As per `IERC4626.Deposit`.
    /// @param owner As per `IERC4626.Deposit`.
    /// @param assets As per `IERC4626.Deposit`.
    /// @param shares As per `IERC4626.Deposit`.
    /// @param id As per `IERC1155.TransferSingle`.
    /// @param receiptInformation As per `ReceiptInformation`.
    event Deposit(address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation);

    /// Similar to IERC4626 withdraw but with receipt ID.
    /// @param sender As per `IERC4626.Withdraw`.
    /// @param receiver As per `IERC4626.Withdraw`.
    /// @param owner As per `IERC4626.Withdraw`.
    /// @param assets As per `IERC4626.Withdraw`.
    /// @param shares As per `IERC4626.Withdraw`.
    /// @param id As per `IERC1155.TransferSingle`.
    /// @param receiptInformation As per `ReceiptInformation`.
    event Withdraw(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 id,
        bytes receiptInformation
    );

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets, uint256 id) external payable returns (uint256);

    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256);

    function maxDeposit(address) external pure returns (uint256);

    function maxMint(address) external pure returns (uint256);

    function previewDeposit(uint256 assets, uint256 minShareRatio) external payable returns (uint256);

    function previewMint(uint256 shares, uint256 minShareRatio) external payable returns (uint256);

    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes calldata receiptInformation)
        external
        payable
        returns (uint256);

    function mint(uint256 shares, address receiver, uint256 minMinShareRatio, bytes calldata receiptInformation)
        external
        payable
        returns (uint256);

    function maxWithdraw(address owner, uint256 id) external view returns (uint256);

    function previewWithdraw(uint256 shares, uint256 id) external view returns (uint256);

    function withdraw(uint256 assets, address receiver, address owner, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256);

    /// Mimics ERC4626 `maxRedeem` with the receipt ID to redeem with to be
    /// passed in.
    /// @param owner As per IERC4626 `maxRedeem`.
    /// @param id The reference id to redeem against.
    function maxRedeem(address owner, uint256 id) external view returns (uint256);

    /// Mimics ERC4626 `previewRedeem` with the receipt ID to redeem with to be
    /// passed in.
    /// @param shares As per IERC4626 `previewRedeem`.
    /// @param id The reference id to redeem against.
    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256);

    /// Mimics ERC4626 `redeem` with the receipt ID to redeem with to be passed
    /// in. Shares MUST be redeemed 1:1 by amount for the receipt ID from the
    /// owner.
    /// @param shares As per IERC4626 `redeem`.
    /// @param receiver As per IERC4626 `redeem`.
    /// @param owner As per IERC4626 `redeem`.
    /// @param id The reference id to redeem against. The owner MUST hold
    /// a receipt with id and it will be used to calculate the share ratio.
    /// @param receiptInformation Associated receipt data for the redemption.
    function redeem(uint256 shares, address receiver, address owner, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256);

    /// Need to accept refunds from the oracle.
    fallback() external payable;

    /// Need to accept refunds from the oracle.
    receive() external payable;
}
