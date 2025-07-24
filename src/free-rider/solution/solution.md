# Free Rider NFT Marketplace Exploit

• **Flash loan for capital** - Borrow 15 ETH from Uniswap V2 pair to fund the attack since we only start with 0.1 ETH
• **Batch buying vulnerability** - Use `buyMany()` to purchase all 6 NFTs for just 15 ETH instead of 90 ETH (msg.value reused across loop)
• **Payment after transfer bug** - Marketplace pays current owner (us) instead of original seller, giving us 90 ETH back for our 15 ETH purchase
• **Claim bounty** - Transfer all 6 NFTs to recovery manager to receive additional bounty, then repay flash loan with profit
