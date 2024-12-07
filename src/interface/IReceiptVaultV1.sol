// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

/// @title IReceiptVaultV1
/// @notice An ERC4626-like interface for a vault that issues ERC1155 receipts
/// alongside the ERC20 share tokens that it mints. The similarity to ERC4626
/// should make it familiar to auditors and implementors alike.
///
/// There are some key differences to ERC4626:
/// - ERC20 share mint/burn functions are all done within the context of a
///   specific ERC1155 receipt ID.
/// - Minting functions are all payable and NOT view, including previews, as they
///   MAY rely on paid external state such as oracles.
///
/// Mints and burns are to be done 1:1 for the ERC20 shares and ERC1155 receipt
/// amounts. This enforces the total supply of the shares always matches the
/// total supply across all receipts. If a user does not have enough shares or
/// receipts to burn, the withdraw/redeem functions MUST revert.
///
/// The ERC4626 standard can be found at https://eips.ethereum.org/EIPS/eip-4626
/// Relevant excerpts are included in the function comments.
interface IReceiptVaultV1 {
    /// Similar to receipt information but for the entire vault. Anyone can emit
    /// any data about the vault, it is up to indexers to filter and clients to
    /// interpret the data.
    /// @param sender Sender of the receipt vault information.
    /// @param vaultInformation The vault information.
    event ReceiptVaultInformation(address sender, bytes vaultInformation);

    /// Similar to IERC4626 `Deposit` but with receipt ID and information.
    /// @param sender As per `IERC4626.Deposit`.
    /// @param owner As per `IERC4626.Deposit`.
    /// @param assets As per `IERC4626.Deposit`.
    /// @param shares As per `IERC4626.Deposit`.
    /// @param id As per `IERC1155.TransferSingle`.
    /// @param receiptInformation As per `ReceiptInformation`.
    event Deposit(address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation);

    /// Similar to IERC4626 `Withdraw` but with receipt ID.
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

    /// Exactly as per IERC4626 `asset`.
    ///
    /// > The address of the underlying token used for the Vault for accounting,
    /// > depositing, and withdrawing.
    /// >
    /// > MUST be an EIP-20 token contract.
    /// >
    /// > MUST NOT revert.
    ///
    /// @return assetTokenAddress As per IERC4626 `asset`.
    function asset() external view returns (address assetTokenAddress);

    /// Exactly as per IERC4626 `totalAssets`.
    ///
    /// > Total amount of the underlying asset that is “managed” by Vault.
    /// >
    /// > SHOULD include any compounding that occurs from yield.
    /// >
    /// > MUST be inclusive of any fees that are charged against assets in the
    /// > Vault.
    /// >
    /// > MUST NOT revert.
    ///
    /// @return totalManagedAssets As per IERC4626 `totalAssets`.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// Similar to IERC4626 `convertToShares` but with receipt ID.
    ///
    /// > The amount of shares that the Vault would exchange for the amount of
    /// > assets provided, in an ideal scenario where all the conditions are met.
    /// >
    /// > MUST NOT be inclusive of any fees that are charged against assets in
    /// > the Vault.
    /// >
    /// > MUST NOT show any variations depending on the caller.
    /// >
    /// > MUST NOT reflect slippage or other on-chain conditions, when performing
    /// > the actual exchange.
    /// >
    /// > MUST NOT revert unless due to integer overflow caused by an
    /// > unreasonably large input.
    /// >
    /// > MUST round down towards 0.
    /// >
    /// > This calculation MAY NOT reflect the “per-user” price-per-share, and
    /// > instead should reflect the “average-user’s” price-per-share, meaning
    /// > what the average user should expect to see when exchanging to and from.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// convert to shares with. Implementing contracts MAY provide different
    /// conversion rates for different receipt IDs.
    ///
    /// @param assets As per IERC4626 `convertToShares`.
    /// @param id The receipt ID to convert to shares with.
    /// @return shares As per IERC4626 `convertToShares`.
    function convertToShares(uint256 assets, uint256 id) external payable returns (uint256 shares);

    /// Similar to IERC4626 `convertToAssets` but with receipt ID.
    ///
    /// > The amount of assets that the Vault would exchange for the amount of
    /// > shares provided, in an ideal scenario where all the conditions are met.
    /// >
    /// > MUST NOT be inclusive of any fees that are charged against assets in
    /// > the Vault.
    /// >
    /// > MUST NOT show any variations depending on the caller.
    /// >
    /// > MUST NOT reflect slippage or other on-chain conditions, when performing
    /// > the actual exchange.
    /// >
    /// > MUST NOT revert unless due to integer overflow caused by an
    /// > unreasonably large input.
    /// >
    /// > MUST round down towards 0.
    /// >
    /// > This calculation MAY NOT reflect the “per-user” price-per-share, and
    /// > instead should reflect the “average-user’s” price-per-share, meaning
    /// > what the average user should expect to see when exchanging to and from.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// convert to assets with. Implementing contracts MAY provide different
    /// conversion rates for different receipt IDs.
    ///
    /// @param shares As per IERC4626 `convertToAssets`.
    /// @param id The receipt ID to convert to assets with.
    /// @return assets As per IERC4626 `convertToAssets`.
    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256 assets);

    /// Exactly as per IERC4626 `maxDeposit`.
    ///
    /// > Maximum amount of the underlying asset that can be deposited into the
    /// > Vault for the receiver, through a deposit call.
    /// >
    /// > MUST return the maximum amount of assets deposit would allow to be
    /// > deposited for receiver and not cause a revert, which MUST NOT be higher
    /// > than the actual maximum that would be accepted (it should underestimate
    /// > if necessary). This assumes that the user has infinite assets,
    /// > i.e. MUST NOT rely on balanceOf of asset.
    /// >
    /// > MUST factor in both global and user-specific limits, like if deposits
    /// > are entirely disabled (even temporarily) it MUST return 0.
    /// >
    /// > MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of
    /// > assets that may be deposited.
    /// >
    /// > MUST NOT revert.
    ///
    /// @param receiver As per IERC4626 `maxDeposit`.
    /// @return maxAssets As per IERC4626 `maxDeposit`.
    function maxDeposit(address receiver) external pure returns (uint256 maxAssets);

    /// Similar to IERC4626 `previewDeposit` but with min share ratio.
    ///
    /// > Allows an on-chain or off-chain user to simulate the effects of their
    /// > deposit at the current block, given current on-chain conditions.
    /// >
    /// > MUST return as close to and no more than the exact amount of Vault
    /// > shares that would be minted in a deposit call in the same transaction.
    /// > I.e. deposit should return the same or more shares as previewDeposit if
    /// > called in the same transaction.
    /// >
    /// > MUST NOT account for deposit limits like those returned from maxDeposit
    /// > and should always act as though the deposit would be accepted,
    /// > regardless if the user has enough tokens approved, etc.
    /// >
    /// > MUST be inclusive of deposit fees. Integrators should be aware of the
    /// > existence of deposit fees.
    /// >
    /// > MUST NOT revert due to vault specific user/global limits. MAY revert
    /// > due to other conditions that would also cause deposit to revert.
    /// >
    /// > Note that any unfavorable discrepancy between convertToShares and
    /// > previewDeposit SHOULD be considered slippage in share price or some
    /// > other type of condition, meaning the depositor will lose assets by
    /// > depositing.
    ///
    /// Includes an additional `minShareRatio` parameter to specify the minimum
    /// share ratio to deposit with. If the deposit would result in a share ratio
    /// below this value, the preview will revert. This avoids the need for users
    /// to implement wrapper contracts to check the share ratio after depositing,
    /// which is effectively what IERC4626 imposes in practise.
    ///
    /// @param assets As per IERC4626 `previewDeposit`.
    /// @param minShareRatio The minimum share ratio to deposit with.
    /// @return shares As per IERC4626 `previewDeposit`.
    function previewDeposit(uint256 assets, uint256 minShareRatio) external payable returns (uint256 shares);

    /// Similar to IERC4626 `deposit` but with min share ratio and information.
    ///
    /// > Mints shares Vault shares to receiver by depositing exactly assets of
    /// > underlying tokens.
    /// >
    /// > MUST emit the Deposit event.
    /// >
    /// > MUST support EIP-20 approve / transferFrom on asset as a deposit flow.
    /// > MAY support an additional flow in which the underlying tokens are owned
    /// > by the Vault contract before the deposit execution, and are accounted
    /// > for during deposit.
    /// >
    /// > MUST revert if all of assets cannot be deposited (due to deposit limit
    /// > being reached, slippage, the user not approving enough underlying
    /// > tokens to the Vault contract, etc).
    /// >
    /// > Note that most implementations will require pre-approval of the Vault
    /// > with the Vault’s underlying asset token.
    ///
    /// Includes an additional `depositMinShareRatio` parameter to specify the
    /// minimum share ratio to deposit with. If the deposit would result in a
    /// share ratio below this value, the deposit will revert. This avoids the
    /// need for users to implement wrapper contracts to check the share ratio
    /// after depositing, which is effectively what IERC4626 imposes in practise.
    ///
    /// Includes an additional `receiptInformation` parameter to specify the
    /// receipt information to mint the shares with. This is opaque data that
    /// MUST be emitted in the `Deposit` event and MAY be used by depositors to
    /// provide additional context to the deposit for offchain systems.
    ///
    /// @param assets As per IERC4626 `deposit`.
    /// @param receiver As per IERC4626 `deposit`.
    /// @param depositMinShareRatio The minimum share ratio to deposit with.
    /// @param receiptInformation The receipt information to mint the shares
    /// with.
    /// @return shares As per IERC4626 `deposit`.
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes calldata receiptInformation)
        external
        payable
        returns (uint256 shares);

    /// Exactly as per IERC4626 `maxMint`.
    ///
    /// > Maximum amount of shares that can be minted from the Vault for the
    /// > receiver, through a mint call.
    /// >
    /// > MUST return the maximum amount of shares mint would allow to be
    /// > deposited to receiver and not cause a revert, which MUST NOT be higher
    /// > than the actual maximum that would be accepted (it should underestimate
    /// > if necessary). This assumes that the user has infinite assets,
    /// > i.e. MUST NOT rely on balanceOf of asset.
    /// >
    /// > MUST factor in both global and user-specific limits, like if mints are
    /// > entirely disabled (even temporarily) it MUST return 0.
    /// >
    /// > MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of
    /// > shares that may be minted.
    /// >
    /// > MUST NOT revert.
    ///
    /// @param receiver As per IERC4626 `maxMint`.
    /// @return maxShares As per IERC4626 `maxMint`.
    function maxMint(address receiver) external pure returns (uint256 maxShares);

    /// Similar to IERC4626 `previewMint` but with min share ratio.
    ///
    /// > Allows an on-chain or off-chain user to simulate the effects of their
    /// > mint at the current block, given current on-chain conditions.
    /// >
    /// > MUST return as close to and no fewer than the exact amount of assets
    /// > that would be deposited in a mint call in the same transaction.
    /// > I.e. mint should return the same or fewer assets as previewMint if
    /// > called in the same transaction.
    /// >
    /// > MUST NOT account for mint limits like those returned from maxMint and
    /// > should always act as though the mint would be accepted, regardless if
    /// > the user has enough tokens approved, etc.
    /// >
    /// > MUST be inclusive of deposit fees. Integrators should be aware of the
    /// > existence of deposit fees.
    /// >
    /// > MUST NOT revert due to vault specific user/global limits. MAY revert
    /// > due to other conditions that would also cause mint to revert.
    /// >
    /// > Note that any unfavorable discrepancy between convertToAssets and
    /// > previewMint SHOULD be considered slippage in share price or some other
    /// > type of condition, meaning the depositor will lose assets by minting.
    ///
    /// Includes an additional `minShareRatio` parameter to specify the minimum
    /// share ratio to mint with. If the mint would result in a share ratio below
    /// this value, the preview will revert. This avoids the need for users to
    /// implement wrapper contracts to check the share ratio after minting, which
    /// is effectively what IERC4626 imposes in practise.
    ///
    /// @param shares As per IERC4626 `previewMint`.
    /// @param minShareRatio The minimum share ratio to mint with.
    /// @return assets As per IERC4626 `previewMint`.
    function previewMint(uint256 shares, uint256 minShareRatio) external payable returns (uint256 assets);

    /// Similar to IERC4626 `mint` but with min share ratio and information.
    ///
    /// > Mints exactly shares Vault shares to receiver by depositing assets of
    /// > underlying tokens.
    /// >
    /// > MUST emit the Deposit event.
    /// >
    /// > MUST support EIP-20 approve / transferFrom on asset as a mint flow. MAY
    /// > support an additional flow in which the underlying tokens are owned by
    /// > the Vault contract before the mint execution, and are accounted for
    /// > during mint.
    /// >
    /// > MUST revert if all of shares cannot be minted (due to deposit limit
    /// > being reached, slippage, the user not approving enough underlying
    /// > tokens to the Vault contract, etc).
    /// >
    /// > Note that most implementations will require pre-approval of the Vault
    /// > with the Vault’s underlying asset token.
    ///
    /// Includes an additional `minMinShareRatio` parameter to specify the
    /// minimum share ratio to mint with. If the mint would result in a share
    /// ratio below this value, the mint will revert. This avoids the need for
    /// users to implement wrapper contracts to check the share ratio after
    /// minting, which is effectively what IERC4626 imposes in practise.
    ///
    /// Includes an additional `receiptInformation` parameter to specify the
    /// receipt information to mint the shares with. This is opaque data that
    /// MUST be emitted in the `Deposit` event and MAY be used by minters to
    /// provide additional context to the mint for offchain systems.
    ///
    /// @param shares As per IERC4626 `mint`.
    /// @param receiver As per IERC4626 `mint`.
    /// @param minMinShareRatio The minimum share ratio to mint with.
    /// @param receiptInformation The receipt information to mint the shares
    /// with.
    /// @return assets As per IERC4626 `mint`.
    function mint(uint256 shares, address receiver, uint256 minMinShareRatio, bytes calldata receiptInformation)
        external
        payable
        returns (uint256 assets);

    /// Similar to IERC4626 `maxWithdraw` but with receipt ID.
    ///
    /// > Maximum amount of the underlying asset that can be withdrawn from the
    /// > owner balance in the Vault, through a withdraw call.
    /// >
    /// > MUST return the maximum amount of assets that could be transferred from
    /// > owner through withdraw and not cause a revert, which MUST NOT be higher
    /// > than the actual maximum that would be accepted
    /// > (it should underestimate if necessary).
    /// >
    /// > MUST factor in both global and user-specific limits, like if
    /// > withdrawals are entirely disabled (even temporarily) it MUST return 0.
    /// >
    /// > MUST NOT revert.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// withdraw with. Implementing contracts MAY provide different withdrawal
    /// limits for different receipt IDs.
    ///
    /// @param owner As per IERC4626 `maxWithdraw`.
    /// @param id The receipt ID to withdraw with.
    /// @return maxAssets As per IERC4626 `maxWithdraw`.
    function maxWithdraw(address owner, uint256 id) external view returns (uint256 maxAssets);

    /// Similar to IERC4626 `previewWithdraw` but with receipt ID.
    ///
    /// > Allows an on-chain or off-chain user to simulate the effects of their
    /// > withdrawal at the current block, given current on-chain conditions.
    /// >
    /// > MUST return as close to and no fewer than the exact amount of Vault
    /// > shares that would be burned in a withdraw call in the same transaction.
    /// > I.e. withdraw should return the same or fewer shares as previewWithdraw
    /// > if called in the same transaction.
    /// >
    /// > MUST NOT account for withdrawal limits like those returned from
    /// > maxWithdraw and should always act as though the withdrawal would be
    /// > accepted, regardless if the user has enough shares, etc.
    /// >
    /// > MUST be inclusive of withdrawal fees. Integrators should be aware of
    /// > the existence of withdrawal fees.
    /// >
    /// > MUST NOT revert due to vault specific user/global limits. MAY revert
    /// > due to other conditions that would also cause withdraw to revert.
    /// >
    /// > Note that any unfavorable discrepancy between convertToShares and
    /// > previewWithdraw SHOULD be considered slippage in share price or some
    /// > other type of condition, meaning the depositor will lose assets by
    /// > depositing.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// withdraw with. Implementing contracts MAY provide different withdrawal
    /// limits and conversion rates for different receipt IDs.
    ///
    /// @param assets As per IERC4626 `previewWithdraw`.
    /// @param id The receipt ID to withdraw with.
    /// @return shares As per IERC4626 `previewWithdraw`.
    function previewWithdraw(uint256 assets, uint256 id) external view returns (uint256 shares);

    /// Similar to IERC4626 `withdraw` but with receipt ID and information.
    ///
    /// > Burns shares from owner and sends exactly assets of underlying tokens
    /// > to receiver.
    /// >
    /// > MUST emit the Withdraw event.
    /// >
    /// > MUST support a withdraw flow where the shares are burned from owner
    /// > directly where owner is msg.sender.
    /// >
    /// > MUST support a withdraw flow where the shares are burned from owner
    /// > directly where msg.sender has EIP-20 approval over the shares of owner.
    /// >
    /// > MAY support an additional flow in which the shares are transferred to
    /// > the Vault contract before the withdraw execution, and are accounted for
    /// > during withdraw.
    /// >
    /// > SHOULD check msg.sender can spend owner funds, assets needs to be
    /// > converted to shares and shares should be checked for allowance.
    /// >
    /// > MUST revert if all of assets cannot be withdrawn
    /// > (due to withdrawal limit being reached, slippage, the owner not having
    /// > enough shares, etc).
    /// >
    /// > Note that some implementations will require pre-requesting to the Vault
    /// > before a withdrawal may be performed. Those methods should be performed
    /// > separately.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// withdraw with. Implementing contracts MAY provide different withdrawal
    /// limits and conversion rates for different receipt IDs.
    ///
    /// Includes an additional `receiptInformation` parameter to specify the
    /// receipt information to burn the shares with. This is opaque data that
    /// MAY be used by withdrawers to provide additional context to the withdraw
    /// for offchain systems.
    ///
    /// @param assets As per IERC4626 `withdraw`.
    /// @param receiver As per IERC4626 `withdraw`.
    /// @param owner As per IERC4626 `withdraw`.
    /// @param id The receipt ID to withdraw with.
    /// @param receiptInformation The receipt information to burn the shares
    /// with.
    /// @return shares As per IERC4626 `withdraw`.
    function withdraw(uint256 assets, address receiver, address owner, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256 shares);

    /// Similar to IERC4626 `maxRedeem` but with receipt ID.
    ///
    /// > Maximum amount of Vault shares that can be redeemed from the owner
    /// > balance in the Vault, through a redeem call.
    /// >
    /// > MUST return the maximum amount of shares that could be transferred from
    /// > owner through redeem and not cause a revert, which MUST NOT be higher
    /// > than the actual maximum that would be accepted
    /// > (it should underestimate if necessary).
    /// >
    /// > MUST factor in both global and user-specific limits, like if redemption
    /// > is entirely disabled (even temporarily) it MUST return 0.
    /// >
    /// > MUST NOT revert.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to redeem
    /// with. Implementing contracts MAY provide different redemption limits for
    /// different receipt IDs.
    ///
    /// @param owner As per IERC4626 `maxRedeem`.
    /// @param id The reference id to redeem against.
    /// @return maxShares As per IERC4626 `maxRedeem`.
    function maxRedeem(address owner, uint256 id) external view returns (uint256 maxShares);

    /// Similar to IERC4626 `previewRedeem` but with receipt ID.
    ///
    /// > Allows an on-chain or off-chain user to simulate the effects of their
    /// > redeemption at the current block, given current on-chain conditions.
    /// >
    /// > MUST return as close to and no more than the exact amount of assets
    /// > that would be withdrawn in a redeem call in the same transaction.
    /// > I.e. redeem should return the same or more assets as previewRedeem if
    /// > called in the same transaction.
    /// >
    /// > MUST NOT account for redemption limits like those returned from
    /// > maxRedeem and should always act as though the redemption would be
    /// > accepted, regardless if the user has enough shares, etc.
    /// >
    /// > MUST be inclusive of withdrawal fees. Integrators should be aware of
    /// > the existence of withdrawal fees.
    /// >
    /// > MUST NOT revert due to vault specific user/global limits. MAY revert
    /// > due to other conditions that would also cause redeem to revert.
    /// >
    /// > Note that any unfavorable discrepancy between convertToAssets and
    /// > previewRedeem SHOULD be considered slippage in share price or some
    /// > other type of condition, meaning the depositor will lose assets by
    /// > redeeming.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to
    /// redeem with. Implementing contracts MAY provide different redemption
    /// limits and conversion rates for different receipt IDs.
    ///
    /// @param shares As per IERC4626 `previewRedeem`.
    /// @param id The reference id to redeem against.
    /// @return assets As per IERC4626 `previewRedeem`.
    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256 assets);

    /// Similar to IERC4626 `redeem` but with receipt ID and information.
    ///
    /// > Burns exactly shares from owner and sends assets of underlying tokens
    /// > to receiver.
    /// >
    /// > MUST emit the Withdraw event.
    /// >
    /// > MUST support a redeem flow where the shares are burned from owner
    /// > directly where owner is msg.sender.
    /// >
    /// > MUST support a redeem flow where the shares are burned from owner
    /// > directly where msg.sender has EIP-20 approval over the shares of owner.
    /// >
    /// > MAY support an additional flow in which the shares are transferred to
    /// > the Vault contract before the redeem execution, and are accounted for
    /// > during redeem.
    /// >
    /// > SHOULD check msg.sender can spend owner funds using allowance.
    /// >
    /// > MUST revert if all of shares cannot be redeemed
    /// > (due to withdrawal limit being reached, slippage, the owner not having
    /// > enough shares, etc).
    /// >
    /// > Note that some implementations will require pre-requesting to the Vault
    /// > before a withdrawal may be performed. Those methods should be performed
    /// > separately.
    ///
    /// Includes an additional `id` parameter to specify the receipt ID to redeem
    /// with. Implementing contracts MAY provide different redemption limits and
    /// conversion rates for different receipt IDs.
    ///
    /// @param shares As per IERC4626 `redeem`.
    /// @param receiver As per IERC4626 `redeem`.
    /// @param owner As per IERC4626 `redeem`.
    /// @param id The reference id to redeem against. The owner MUST hold
    /// a receipt with id and it will be used to calculate the share ratio.
    /// @param receiptInformation Associated receipt data for the redemption.
    /// @return assets As per IERC4626 `redeem`.
    function redeem(uint256 shares, address receiver, address owner, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256 assets);

    /// Needed to accept refunds from the oracle if applicable.
    fallback() external payable;

    /// Needed to accept refunds from the oracle if applicable.
    receive() external payable;
}
