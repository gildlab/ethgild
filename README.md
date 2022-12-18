# EthGild

## Wiki

Information on contract usage and economics can be found at [wiki.gildlab.xyz](https://wiki.gildlab.xyz).

## Dev stuff

### Local environment & CI

Uses nixos.

Install `nix-shell` - https://nixos.org/download.html.

Run `nix-shell` in this repo to drop into the shell. Please ONLY use the nix
shell version of `npm` for all development, no yarn or BYO npm, etc. as this helps
avoid subtle corruption of lock files due to package manager version mismatch.

From here run [hardhat](https://hardhat.org/) as normal.

Read the `default.nix` file to find some additional commands included for dev and
CI usage.