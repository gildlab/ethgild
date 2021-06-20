# EthGild

A hybrid erc20 and erc1155 that mints/burns at a reference gold price from chainlink oracles, denominated in ETH.

The erc20 is called `EthGild` with symbol `ETHg`. It works much like wrapping/unwrapping `ETH` to `WETH`.

Send ETH to the payable `gild` function to gild it and receive ETHg erc20 and erc1155 in equal amounts at current reference gold price.

Call `ungild` to burn 100.1% erc20 against any erc1155 to ungild the ETH that was created against that erc1155.

Trade either the erc20 and/or the erc1155 on any markets that support those standards.

## More documentation

[More information in the comments of `ethgild.sol`](https://github.com/thedavidmeister/ethgild/blob/main/contracts/ethgild.sol).

I tried about 5x different documentation generators for solidity but they were all old, broken and/or too clunky.
Most important is to have the comments on the code as it is deployed onchain, so this readme is a summary only.

If I get a documentation generator working for solidity `0.8.4` I will update this readme and host some docs somewhere :)

## Why would I want to gild ETH?

Because you can sell the ETHg and/or erc1155 to people who want to ungild their ETH or hold/trade gilded ETH.

If that sounds circular, consider the following (oversimplified) example to leverage ETH:

If the market price of ETHg is 0.8x the reference price of gold then gild 1 ETH and buy 0.8 ETH.
If the market price of ETH goes up 50% against gold then sell 0.8 ETH for 1.6x erc20 minted, unlock 1 ETH and sell remaining erc20.

Feel somewhat safe knowing that the market price of ETHg erc20 can never be higher than the reference price of gold.
For example, if the market price of ETHg is 1.1x gold price then gild 1 ETH to buy 1.1 ETH, infinitely.
This means there is an upper limit on the cost to ungild later.

Of course the market price of ETH, erc20, erc1155 and gold are all variable and unpredictable over time.
Hopefully the ETHg erc20 market price volatility is somewhere between ETH and fiat/gold.

## Why would I want to buy ETHg?

You believe that eventually all gilded ETH will want to be ungilded.
You can buy low and sell high.
You can LP on standard AMMs and collect fees with limited IL.

Unlike algorithmic coins, there is real ETH behind every ETHg enforced and tracked by erc1155 tokens.
Unlike pegged coins, there is no active management or explicit definition of what "high" or "low" should be - figure it out.

ETHg is burned at 0.1% faster rate than the erc1155 so a sliver of ETH is trapped for every gilding.
This should provide sustainable demand on the erc20 token, pushing the  market price higher.

As the market price of the erc20 drops the benefits of gilding become less and the incentives to ungild increases.

The more ETHg that is bought or locked in contracts (e.g. an AMM), the more ETH is ungildable.

There is no explicit peg to arbitrage, but very cheap ETHg could quickly lead to a bank run on gilded ETH.
The bank run brings the ETHg price _up_ due to the overburn mechanism and standard AMM bonding curves.

## UNLICENSE

EthGild is public domain and comes with no warranty.

See UNLICENSE for details.

https://unlicense.org/

## How is the reference gold price determined?

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

To run the tests locally run `local-node` and `local-test` in different terminals.

These commands are available from the `nix-shell` and can be reviewed in `shell.nix`.

#### constants

- [x] erc20 name is `EthGild`
- [x] erc20 symbol is `ETHg`
- [x] gild uri is `https://ethgild.crypto/#/id/{id}`
- [x] overburn numerator is `1001`
- [x] overburn denominator is `1000`
- [x] xau decimals for chainlink oracle is `8`
- [x] xau oracle is `0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6`
- [x] eth oracle is `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- [x] erc20 decimals is `18`

#### events

- [x] `Gild` emmitted on `gild` for sender, with price and eth amount
- [x] `Ungild` emmitted on `ungild` for sender, with price and eth amount

#### oracle

- [x] oracle price roughly matches eth/xau from Trading View feed at block specified in local node fork
- [ ] mocked oracle can return different prices

#### gild

- [x] cross reference gilded ETHg against Trading View and Chainlink
- [x] erc1155 minted at oracle price with price * eth amount
- [x] erc20 minted with same amount as erc1155
- [x] multiple signers can create and transfer balances for both erc20 and erc1155
- [x] 100.1% overburn erc20 required for full erc1155 unlock
- [x] eth amount minus gas fees can be ungilded with sufficient erc20
- [x] erc20 burned at 100.1% erc1155 rate
- [x] both erc20 and erc1155 is burned
- [x] signers can only burn their own tokens
- [x] signers need both erc20 and erc1155 to burn and ungild eth
- [x] zero value gild is an error
- [ ] mocked oracle can create two different erc1155 at different prices

#### Fallback

- [x] `fallback` and `receive` both error (user must use payable `gild` function explicitly)

#### ERC20

- [x] Open Zeppelin erc20 constructs correctly with `name` and `symbol`

#### ERC1155

- [x] Open Zeppelin erc1155 constructs correctly with `uri` for any id

#### Reentrant

- [x] `msg.sender` can respond to `gild` with `erc1155Receiver` with reentrant calls
- [x] errors in `erc1155Receiver` on `gild` propagate and error in `EthGild`
- [x] `msg.sender` can respond to `ungild` with `receive` with reentrant calls
- [x] errors in `receive` on `ungild` propagate and error in `EthGild`