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

As the price of the erc20 drops the benefits of vaulting become less and the incentives to unlock vaults increase.

The more erc20 that is bought or locked in contracts (e.g. an AMM), the more ETH is unvaultable.

There is no explicit peg to arbitrage, but very cheap erc20 could quickly lead to a bank run on vaults.