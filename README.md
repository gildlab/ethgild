# sol-ounce

Ounce is both an erc1155 and erc20.
All token behaviour is default Open Zeppelin.
This works because none of the function names collide, or if they do the signature overloads cleanly (e.g. `_mint`).

## Vaulting

Simply send ETH to the contract.
The erc1155 is minted as the current gold price in ETH as its id, and the price multiplied by ETH locked as amount (18 decimals).
The erc20 is minted as the price multiplied by ETH locked as amount (18 decimals).
The ETH locked is whatever is sent to the contract as a normal transaction.

## Unvaulting

The erc1155 id (unvault price) and amount of ETH to unvault must be specified to the unvault function.
The erc1155 under the price id is burned as ETH being unvaulted multiplied by the unvault price.
The erc20 is burned as 1001/1000 times the erc1155 burn.
The ETH amount is sent to `msg.sender`.

## Reentrancy

The erc20 minting and all burning is not reentrant.
But both receive and unvault end with possibly reentrant calls to the msg.sender.
`receive` will attempt to treat the msg.sender as an erc1155 receiver.
`unvault` will call the sender with the appropriate ETH amount.
This should be safe for the contract state but may facilitate creative use-cases.

## Tokenomics

- Hard price cap at 1 ounce of gold.
  - Exceeding this allows to vault 1 eth, sell minted ounces, buy more than 1 eth, repeat infinitely.
- Hard price cap at max recent ETH drawdown.
  - Exceeding this allows all vaults to be unlocked on a market buy of ounces cheaper than the vaulted ETH.
- Ranging between two caps.
  - Sell high to leverage ETH without liquidation threat.
    - Vault 1 ETH for ~1 ETH of ounce, sell ounce for ETH, wait for pump.
    - Unvault original eth for roughly starting ounce price, sell ~2 ETH.
  - Buy low to trap degens.
    - Ultimately every ounce +0.1% must be burned for ETH to be returned.
    - ETH should always be more desirable long term than ounces so eventually the price will recover.
    - Should find a natural equilibrium between vaults and unvaults based on market conditions.
  - Use in range for stable-ish protection of ETH value.
    - If ETH is uncomfortably high then vault and keep ounce.
    - Vaulting is not a trade so is immune to front-running and slippage.
    - Price based on gold oracle so does not rely on fiat for stability.
    - If ETH crashes then ounce probably will too but ounce may recover stability faster.
    - ETH can be unvaulted for 0.1% haircut at any time if market remains strong.
  - Use in range for LP on AMM with low IL.
    - Pair with other gold tokens knowing that oXAU is bounded [0.x-1) with gold price.
    - IL is credibly impermanent.
    - All liquidity on AMM is locking ETH so more liquidity implies tighter price range.
    - Should always be baseline supply/demand from leveraging use-case.
- Applicable to any token/price pair
  - ETH and gold seem the most obvious first pair to experiment with.
  - If it works then basically any token/pair should work as long as there is demand for the base token.

## Administration

- Contract has NO owner or other administrative functions
- Contract has NO upgrades
- This is all HIGHLY EXPERIMENTAL and comes with NO WARRANTY
- The tokenomics are HIGHLY EXPERIMENTAL and NOT FINANCIAL ADVICE
- If this contract is EXPLOITED or contains BUGS
  - There is NO support or compensation
  - There MAY be a NEW contract deployed without the exploit/bug