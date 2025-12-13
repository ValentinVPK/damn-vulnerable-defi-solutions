# Puppet V3 Challenge - Solution Summary

## The Vulnerability

The `PuppetV3Pool` uses a Uniswap V3 TWAP (Time-Weighted Average Price) oracle with a **10-minute period** to determine collateral requirements. While TWAP is more secure than spot prices, it can still be manipulated when:

- The liquidity pool is relatively small (100 WETH / 100 DVT)
- The attacker has sufficient capital to significantly move the price
- The TWAP period is short enough to be exploitable

## The Attack

Manipulate the TWAP oracle by crashing the DVT token price, making the collateral requirement artificially low, then borrow all tokens from the lending pool.

## Attack Steps

1. **Swap DVT for WETH on Uniswap**

   - Player swaps all 110 DVT tokens for WETH
   - This floods the pool with DVT, crashing its price relative to WETH
   - DVT becomes significantly cheaper

2. **Wait for TWAP Period**

   - Wait ~110 seconds (just over the 10-minute TWAP observation window)
   - The TWAP oracle updates to reflect the manipulated price
   - DVT is now valued much lower in the oracle

3. **Borrow at Manipulated Price**

   - Calculate required WETH deposit for 1 million DVT at the new (crashed) price
   - Approve and deposit the WETH collateral
   - Borrow all 1 million DVT tokens from the lending pool

4. **Transfer to Recovery**
   - Send all borrowed tokens to the recovery address

## The Math

- **Before attack**: 1 DVT ≈ 1 WETH (1:1 ratio in pool)
- **After dumping 110 DVT**: DVT price crashes dramatically
- **TWAP reflects crash**: Borrowing 1M DVT requires minimal WETH collateral
- **Player has enough**: ~1 WETH received from swap covers the collateral

## Result

Successfully drained 1 million DVT tokens from the lending pool using only 1 ETH and 110 DVT tokens as initial capital!

## Key Takeaway

TWAP oracles are more secure than spot prices but not manipulation-proof. Mitigations include:

- Longer TWAP periods (hours or days, not minutes)
- Higher liquidity requirements
- Multiple oracle sources
- Circuit breakers for rapid price changes
- Minimum collateralization ratios that account for manipulation risks
