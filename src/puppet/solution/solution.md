# 8. Puppet Pool Oracle Manipulation Attack

• **Manipulate price oracle** - Swap 1000 DVT tokens for ETH on Uniswap V1 to crash token price from 1 ETH to ~0.0001 ETH per DVT
• **Gain additional capital** - Receive ~9.9 ETH from the swap, increasing total available funds from 25 ETH to 34.9 ETH  
• **Exploit crashed price** - Borrow all 100k DVT tokens for only 19.66 ETH collateral (vs 200k ETH at fair price)
• **Execute in single transaction** - Deploy attack contract that pulls tokens, manipulates oracle, and drains lending pool in constructor
