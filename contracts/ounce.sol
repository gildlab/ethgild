// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

// Open Zeppelin imports.
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// # sol-ounce
//
// Ounce is both an erc1155 and erc20.
// All token behaviour is default Open Zeppelin.
// This works because none of the function names collide, or if they do the signature overloads cleanly (e.g. `_mint`).
//
// ## Vaulting
//
// Simply send ETH to the contract.
// The erc1155 is minted as the current gold price in ETH as its id, and the price multiplied by ETH locked as amount (18 decimals).
// The erc20 is minted as the price multiplied by ETH locked as amount (18 decimals).
// The ETH locked is whatever is sent to the contract as a normal transaction.
//
// ## Unvaulting
//
// The erc1155 id (unvault price) and amount of ETH to unvault must be specified to the unvault function.
// The erc1155 under the price id is burned as ETH being unvaulted multiplied by the unvault price.
// The erc20 is burned as 1001/1000 times the erc1155 burn.
// The ETH amount is sent to `msg.sender`.
//
// ## Reentrancy
//
// The erc20 minting and all burning is not reentrant.
// But both receive and unvault end with possibly reentrant calls to the msg.sender.
// `receive` will attempt to treat the msg.sender as an erc1155 receiver.
// `unvault` will call the sender with the appropriate ETH amount.
// This should be safe for the contract state but may facilitate creative use-cases.
//
// ## Tokenomics
//
// - Hard price cap at 1 ounce of gold.
//   - Exceeding this allows to vault 1 eth, sell minted ounces, buy more than 1 eth, repeat infinitely.
// - Hard price cap at max recent ETH drawdown.
//   - Exceeding this allows all vaults to be unlocked on a market buy of ounces cheaper than the vaulted ETH.
// - Ranging between two caps.
//   - Sell high to leverage ETH without liquidation threat.
//     - Vault 1 ETH for ~1 ETH of ounce, sell ounce for ETH, wait for pump.
//     - Unvault original eth for roughly starting ounce price, sell ~2 ETH.
//   - Buy low to trap degens.
//     - Ultimately every ounce +0.1% must be burned for ETH to be returned.
//     - ETH should always be more desirable long term than ounces so eventually the price will recover.
//     - Should find a natural equilibrium between vaults and unvaults based on market conditions.
//   - Use in range for stable-ish protection of ETH value.
//     - If ETH is uncomfortably high then vault and keep ounce.
//     - Vaulting is not a trade so is immune to front-running and slippage.
//     - Price based on gold oracle so does not rely on fiat for stability.
//     - If ETH crashes then ounce probably will too but ounce may recover stability faster.
//     - ETH can be unvaulted for 0.1% haircut at any time if market remains strong.
//   - Use in range for LP on AMM with low IL.
//     - Pair with other gold tokens knowing that oXAU is bounded [0.x-1) with gold price.
//     - IL is credibly impermanent.
//     - All liquidity on AMM is locking ETH so more liquidity implies tighter price range.
//     - Should always be baseline supply/demand from leveraging use-case.
// - Applicable to any token/price pair
//   - ETH and gold seem the most obvious first pair to experiment with.
//   - If it works then basically any token/pair should work as long as there is demand for the base token.
//
// ## Administration
//
// - Contract has NO owner or other administrative functions
// - Contract has NO upgrades
// - This is all HIGHLY EXPERIMENTAL and comes with NO WARRANTY
// - The tokenomics are HIGHLY EXPERIMENTAL and NOT FINANCIAL ADVICE
// - If this contract is EXPLOITED or contains BUGS
//   - There is NO support or compensation
//   - There MAY be a NEW contract deployed without the exploit/bug
contract Ounce is ERC1155, ERC20 {
    // Chainlink oracles are signed integers so we need to handle them as unsigned for price feed.
    using SafeCast for int256;
    using SafeMath for uint256;

    // Both Vault and Unvault events are the same.
    // ETH (un)vaulted is `amount / price`.
    event Vault(address indexed caller, uint256 indexed _price, uint256 indexed amount);
    event Unvault(address indexed caller, uint256 indexed _price, uint256 indexed amount);

    string public constant NAME = "ounce";
    string public constant SYMBOL = "oXAU";
    string public constant VAULT_URI = "https://oxau.crypto/{id}";

    uint256 public constant FEE_NUMERATOR = 1001;
    uint256 public constant FEE_DENOMINATOR = 1000;

    // Chainlink oracles.
    // https://docs.chain.link/docs/ethereum-addresses/
    uint256 public constant XAU_DECIMALS = 8;
    uint256 public constant ETH_DECIMALS = 18;
    AggregatorV3Interface public constant CHAINLINK_XAUUSD = AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
    AggregatorV3Interface public constant CHAINLINK_ETHUSD = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    constructor () ERC20(NAME, SYMBOL) ERC1155(VAULT_URI) { } //solhint-disable no-empty-blocks

    // Returns an oXAU price in ETH or reverts.
    // Internally calls two separate chainlink oracles to factor out the USD price.
    // Ideally we'd avoid referencing USD even for internal math but chainlink doesn't support it.
    function price() public view returns (uint256) {
        ( , int256 _xauUsd, , , ) = CHAINLINK_XAUUSD.latestRoundData();
        ( , int256 _ethUsd, , , ) = CHAINLINK_ETHUSD.latestRoundData();
        return _ethUsd.toUint256().mul(10 ** XAU_DECIMALS).div(_xauUsd.toUint256());
    }

    // Burn roughly equal (1001:1000 ratio) erc20:erc1155 to receive initial ETH refund.
    function unvault(uint256 _price, uint256 _amountEth) external {

        uint256 _amount = _amountEth.mul(_price).div(10 ** XAU_DECIMALS);
        emit Unvault(msg.sender, _price, _amountEth);
        // ERC20 burn.
        // Slightly more than ERC1155 burn.
        _burn(msg.sender, _amount.mul(FEE_NUMERATOR).div(FEE_DENOMINATOR));
        // ERC1155 burn.
        _burn(msg.sender, _price, _amount);
        // ETH refund.
        // Reentrant.
        (bool _refundSuccess, ) = msg.sender.call{value: _amountEth}(""); // solhint-disable avoid-low-level-calls
        require(_refundSuccess, "ETH_REFUND");
    }

    // Send ETH to the contract to receive equal parts erc20 and erc1155.
    receive() external payable {
        // checks.
        require(msg.value > 0, "ZERO_VALUE");

        // oXAU price in ETH.
        uint256 _price = price();

        // Amount of oXAU to mint.
        uint256 _amount = msg.value.mul(_price).div(10 ** XAU_DECIMALS);

        // ERC20 mint.
        emit Vault(msg.sender, _price, _amount);
        _mint(msg.sender, _amount);

        // ERC1155 mint.
        // Reentrant due to call to erc1155 receiver.
        _mint(msg.sender, _price, _amount, "");
    }
}