# sol-ounce

**THIS IS AN EXPERIMENT. MIT LICENSE. THAT MEANS NO WARRANTY.**

A hybrid erc20 and erc1155 that mints/burns at the current gold price denominated in ETH.

Not a stable coin.

No pegs. No collateral ratios. No DAOs. No admins. No upgrades. No liquidations. No complex contracts.

Send ETH to the contract to receive erc20 and erc1155 in equal amounts at current gold price.

Burn 100.1% erc20 against any erc1155 to unlock the ETH that was created against that erc1155.

Trade either the erc20 and/or the erc1155 on any markets that support those standards.

More information in the comments on `Ounce.sol`.
I tried about 5x different documentation generators for solidity but they were all old, broken and/or too clunky.
Most important is to have the comments on the code as it is deployed onchain, so this readme is a summary only.

## Why would I want to vault ETH?

Because you can sell the erc20 and/or erc1155 to people who want to unlock ETH.

If that sounds circular, consider the following (oversimplified) example to leverage ETH:

If the market price of the erc20 is 0.8x the price of gold then vault 1 ETH and buy 0.8 ETH.
If the price of ETH goes up 50% against gold then sell 0.8 ETH for 1.6x erc20 minted, unlock 1 ETH and sell remaining erc20.

Feel somewhat safe knowing that the price of the erc20 can never be higher than the price of gold.
For example, if the price of erc20 is 1.1x gold price then vault 1 ETH to buy 1.1 ETH, infinitely.

Of course the price of ETH, erc20, erc1155 and gold are all variable and unpredictable over time.
_Hopefully_ the erc20 price volatility is somewhere between ETH and fiat/gold.

## Why would I want to buy the erc20?

Because you believe that _eventually_ all vaulted ETH will want to be unvaulted by _somebody_.
Therefore you can buy low and sell high.
Therefore you can LP on standard AMMs and collect fees with limited IL.

Actually the erc20 is burned at 0.1% faster rate than the erc1155 so a sliver of ETH is trapped in every vault.
This should provide sustainable demand on the erc20 token, pushing the price higher.

As the price of the erc20 drops the benefits of vaulting become less and the incentives to unlock vaults increase.

The more erc20 that is bought or locked in contracts (e.g. an AMM), the more ETH is unvaultable.

There is no explicit peg to arbitrage, but very cheap erc20 could quickly lead to a bank run on vaults.
The bank run is safe because every erc20 minted is mapped to a specific ETH reserve by the erc1155.

## How is the gold price determined?

Chainlink oracles.

## Dev stuff

### Local environment & CI

Uses nixos.

Install `nix-shell` - https://nixos.org/download.html.

Run `nix-shell` in this repo to drop into the shell.

From here run hardhat as normal.

Some additional commands are included for dev.

`local-node` - runs a hardhat node forked at a specific block that has a known oracle price for testing against.
`local-test` - runs hardhat tests against the local node
`security-check` - runs slither security scan
`ci-lint` - run solhint against the contract

Note that the security check and lints run on CI but the hardhat tests do not.

This is because i'm not sure the best way to get the local node running on CI. `@TODO`.

### Tests

#### constants

- [x] erc20 name is `Ounce`
- [x] erc20 symbol is `oXAU`
- [x] vault uri is `https://oxau.crypto/{id}`
- [x] overburn numerator is `1001`
- [x] overburn denominator is `1000`
- [x] xau decimals for chainlink oracle is `8`
- [x] xau oracle is `0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6`
- [x] eth oracle is `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- [x] erc20 decimals is `18`

#### events

- [x] `Vault` emmitted on `receive` for sender, with price and eth amount
- [x] `Vault` emmitted on `fallback` for sender, with price and eth amount
- [x] `Unvault` emmitted on `unvault` for sender, with price and eth amount

#### oracle

- [x] oracle price roughly matches eth/xau from Trading View feed at block specified in local node fork
- [ ] mocked oracle can return different prices

#### vault

- [x] erc1155 minted at oracle price with price * eth amount
- [x] erc20 minted with same amount as erc1155
- [x] multiple signers can create and transfer balances for both erc20 and erc1155
- [x] 100.1% overburn erc20 required for full erc1155 unlock
- [x] eth amount minus gas fees can be unvaulted with sufficient erc20
- [x] erc20 burned at 100.1% erc1155 rate
- [x] both erc20 and erc1155 is burned
- [x] signers can only burn their own tokens
- [x] signers need both erc20 and erc1155 to burn and unvault eth
- [ ] mocked oracle can create two different erc1155 at different prices