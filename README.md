# EthGild

## High Level

Defines and implements the concept of a "Receipt Vault".

Very similar to an ERC4626 vault https://eips.ethereum.org/EIPS/eip-4626.

The main difference is that each mint/burn has an associated ERC1155 receipt
representing the mint/burn event https://eips.ethereum.org/EIPS/eip-1155.

The ID of the mint/burn receipt somehow encodes the identity of the mint/burn
event, and the amount matches the number of ERC20 shares that are minted/burned.

This implies that the ERC1155 receipts are also burned 1:1 with ERC20 shares
if/when a burn happens, and that receipt holders are the only users capable of
burning shares.

The utility of this approach is that the receipt allows information about the
_justification_ of the mint to be encoded onchain.

For example, if this was used for some real world asset (RWA) like a bar of gold,
the 1155 receipt can map its ID to some offchain evidence of the bar of gold in
custody in a vault somewhere.

If some bar was to be taken out of custody, the associated receipt must be burned,
which means the associated ERC20 shares must be burned. This ensures that the
fungible shares in circulation are all backed 1:1 with mint/burn justifications.

`OffchainAssetReceiptVault.sol` is a concrete implementation of RWA minting.

The same approach can be applied to onchain collateral, allowing for vault
tokenomics other than the standard ERC4626 style approach of minting shares in
the same ratio as deposits.

This can allow for novel onchain mechanics where mint/burning of ERC20 tokens is
decoupled from previous/future mint burns, such as referencing external oracles
for share rates, and recording that rate in the associated ERC1155.

`ERC20PriceOracleReceiptVault.sol` is a concrete implementation of onchain oracle
minting.

## Dev stuff

### Local environment & CI

Uses nixos.

Install `nix develop` - https://nixos.org/download.html.

Run `nix develop` in this repo to drop into the shell. Please ONLY use the nix
version of `foundry` for development, to ensure versions are all compatible.

Read the `flake.nix` file to find some additional commands included for dev and
CI usage.

## Legal stuff

Everything is under DecentraLicense 1.0 (DCL-1.0) which can be found in `LICENSES/`.

This is basically `CAL-1.0` which is an open source license
https://opensource.org/license/cal-1-0

The non-legal summary of DCL-1.0 is that the source is open, as expected, but
also user data in the systems that this code runs on must also be made available
to those users as relevant, and that private keys remain private.

Roughly it's "not your keys, not your coins" aware, as close as we could get in
legalese.

This is the default situation on permissionless blockchains, so shouldn't require
any additional effort by dev-users to adhere to the license terms.

This repo is REUSE 3.2 compliant https://reuse.software/spec-3.2/ and compatible
with `reuse` tooling (also available in the nix shell here).

```
nix develop -c reuse lint
```