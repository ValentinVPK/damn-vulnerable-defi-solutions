// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract PuppetPool is ReentrancyGuard {
    using Address for address payable;

    uint256 public constant DEPOSIT_FACTOR = 2;

    address public immutable uniswapPair;
    DamnValuableToken public immutable token;

    mapping(address => uint256) public deposits;

    error NotEnoughCollateral();
    error TransferFailed();

    event Borrowed(address indexed account, address recipient, uint256 depositRequired, uint256 borrowAmount);

    constructor(address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing tokens by first depositing two times their value in ETH
    function borrow(uint256 amount, address recipient) external payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(amount);

        if (msg.value < depositRequired) {
            revert NotEnoughCollateral();
        }

        if (msg.value > depositRequired) {
            unchecked {
                payable(msg.sender).sendValue(msg.value - depositRequired);
            }
        }

        unchecked {
            deposits[msg.sender] += depositRequired;
        }

        // Fails if the pool doesn't have enough tokens in liquidity
        if (!token.transfer(recipient, amount)) {
            revert TransferFailed();
        }

        emit Borrowed(msg.sender, recipient, depositRequired, amount);
    }

    /**
     * @notice Calculates ETH deposit required to borrow a given amount of tokens
     * @param amount Amount of tokens to borrow
     * @return Required ETH deposit in wei
     *
     * @dev Formula: amount * oraclePrice * DEPOSIT_FACTOR / 10^18
     *
     * Example calculation:
     * - Want to borrow: 20 tokens (20 * 10^18 wei)
     * - Oracle price: 0.1 ETH per token (10^17 wei per token)
     * - DEPOSIT_FACTOR: 2 (requires 2x collateral)
     * - Calculation: 20 * 10^17 * 2 / 10^18 = 4 ETH required
     */
    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * DEPOSIT_FACTOR / 10 ** 18;
    }

    /**
     * @notice Computes token price in wei based on Uniswap pair reserves
     * @return Token price in wei (how much ETH per token)
     *
     * @dev Formula: (ETH_balance * 10^18) / token_balance
     *
     * Example calculation:
     * - ETH in pair: 10 ETH (10 * 10^18 wei)
     * - Tokens in pair: 10 tokens (10 * 10^18 wei)
     * - Price = (10 * 10^18 * 10^18) / (10 * 10^18) = 10^18 wei per token
     * - This means: 1 token = 1 ETH
     *
     * Note: This price can be manipulated by swapping large amounts in Uniswap V1
     *
     * REALISTIC UNISWAP V1 ATTACK SCENARIO:
     * Starting conditions:
     * - Player has: 25 ETH + 1000 DVT tokens
     * - Uniswap has: 10 ETH + 10 DVT tokens (k = 100)
     * - Goal: Borrow all 100k DVT from lending pool
     *
     * Step 1: Sell 1000 DVT tokens to Uniswap for ETH
     * - Constant product: x * y = k = 100
     * - After adding 1000 DVT: new_DVT = 10 + 1000 = 1010
     * - New ETH balance: 100 / 1010 ≈ 0.099 ETH
     * - ETH received: 10 - 0.099 = 9.901 ETH
     * - New price: 0.099 * 10^18 / 1010 ≈ 9.8 * 10^13 wei per token
     * - This means: 1 DVT ≈ 0.000098 ETH (price crashed 99.99%!)
     *
     * Step 2: Borrow all tokens with crashed price
     * - Total ETH available: 25 + 9.901 = 34.901 ETH
     * - Collateral needed: 100,000 * 0.000098 * 2 = 19.6 ETH
     * - Attack succeeds! You get 100k DVT for only 19.6 ETH vs 200k ETH at fair price
     * - Profit: ~180k ETH worth of value gained!
     */
    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
}
