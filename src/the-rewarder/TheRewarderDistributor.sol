// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

struct Distribution {
    uint256 remaining;
    uint256 nextBatchNumber;
    mapping(uint256 batchNumber => bytes32 root) roots;
    mapping(address claimer => mapping(uint256 word => uint256 bits)) claims;
}

struct Claim {
    uint256 batchNumber;
    uint256 amount;
    uint256 tokenIndex;
    bytes32[] proof;
}

/**
 * An efficient token distributor contract based on Merkle proofs and bitmaps
 */
contract TheRewarderDistributor {
    using BitMaps for BitMaps.BitMap;

    address public immutable owner = msg.sender;

    mapping(IERC20 token => Distribution) public distributions;
    // WETH -> Distribution || DVT -> Distribution (Само 2 елемента)

    error StillDistributing();
    error InvalidRoot();
    error AlreadyClaimed();
    error InvalidProof();
    error NotEnoughTokensToDistribute();

    event NewDistribution(IERC20 token, uint256 batchNumber, bytes32 newMerkleRoot, uint256 totalAmount);

    function getRemaining(address token) external view returns (uint256) {
        return distributions[IERC20(token)].remaining;
    }

    function getNextBatchNumber(address token) external view returns (uint256) {
        return distributions[IERC20(token)].nextBatchNumber;
    }

    function getRoot(address token, uint256 batchNumber) external view returns (bytes32) {
        return distributions[IERC20(token)].roots[batchNumber];
    }

    // За всеки ERC-20 токен имаме Distribution, който се идентифицира с nextBatchNumber
    // При създаването на Distribution, първо се проверява дали има remaining стойност (remaining > 0), Ако има, се хвърля грешка и не се създава Distribution
    // След проверка и на другите параметри, текущия Distribution се ъпдейтва като remaining = amount,  nextBatchNumber++, newRoot се задава на текущия batchNumber
    function createDistribution(IERC20 token, bytes32 newRoot, uint256 amount) external {
        // @audit-info В задачата казват, че токените които се поддържат от контракта са WETH и DVT, но тук нямаме проверка за това.
        if (amount == 0) revert NotEnoughTokensToDistribute();
        if (newRoot == bytes32(0)) revert InvalidRoot();
        if (distributions[token].remaining != 0) revert StillDistributing();

        // Ako e purviq distribution shte poluchim:
        /**
         *
         * WETH -> {
         *  remaining: amount1,
         *  roots[0] -> newRoot,
         *  nextBatchNumber: 1
         * }
         *
         * Ako e vtoriq distribution shte poluchim:
         *
         * WETH -> {
         *  remaining: amount2,
         *  roots[0] -> oldRoot,
         *  roots[1] -> newRoot
         *  nextBatchNumber: 2
         */
        distributions[token].remaining = amount; // ✅

        // ✅
        uint256 batchNumber = distributions[token].nextBatchNumber;
        distributions[token].roots[batchNumber] = newRoot;
        distributions[token].nextBatchNumber++;

        // @audit-info трябва преди да викнем createDistribution, да approve-нем този contract да харчи токените ни
        SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), amount);

        emit NewDistribution(token, batchNumber, newRoot, amount);
    }

    // Ако distribution-a на token е с remaining = 0, целият баланс на токена в контракта се изпраща на owner-a
    function clean(IERC20[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = tokens[i];
            if (distributions[token].remaining == 0) {
                token.transfer(owner, token.balanceOf(address(this)));
            }
        }
    }

    // Allow claiming rewards of multiple tokens in a single transaction
    // struct Claim {
    //     uint256 batchNumber;
    //     uint256 amount;
    //     uint256 tokenIndex;
    //     bytes32[] proof;
    // }
    // Това е във всеки Distribution:
    // mapping(address claimer => mapping(uint256 word => uint256 bits)) claims;

    // Create Alice's claims
    //     Claim[] memory claims = new Claim[](2);

    // First, the DVT claim
    //     claims[0] = Claim({
    //         batchNumber: 0, // claim corresponds to first DVT batch
    //         amount: ALICE_DVT_CLAIM_AMOUNT,
    //         tokenIndex: 0, // claim corresponds to first token in `tokensToClaim` array
    //         proof: merkle.getProof(dvtLeaves, 2) // Alice's address is at index 2
    //     });

    //  And then, the WETH claim
    //     claims[1] = Claim({
    //         batchNumber: 0, // claim corresponds to first WETH batch
    //         amount: ALICE_WETH_CLAIM_AMOUNT,
    //         tokenIndex: 1, // claim corresponds to second token in `tokensToClaim` array
    //         proof: merkle.getProof(wethLeaves, 2) // Alice's address is at index 2
    //     });

    function claimRewards(Claim[] memory inputClaims, IERC20[] memory inputTokens) external {
        Claim memory inputClaim;
        IERC20 token;
        uint256 bitsSet; // accumulator
        uint256 amount;

        for (uint256 i = 0; i < inputClaims.length; i++) {
            inputClaim = inputClaims[i];

            uint256 wordPosition = inputClaim.batchNumber / 256; // 256 bita
            uint256 bitPosition = inputClaim.batchNumber % 256;

            if (token != inputTokens[inputClaim.tokenIndex]) {
                if (address(token) != address(0)) {
                    if (!_setClaimed(token, amount, wordPosition, bitsSet)) revert AlreadyClaimed();
                }

                token = inputTokens[inputClaim.tokenIndex];
                bitsSet = 1 << bitPosition; // set bit at given position
                amount = inputClaim.amount;
            } else {
                bitsSet = bitsSet | 1 << bitPosition;
                amount += inputClaim.amount;
            }

            // for the last claim
            if (i == inputClaims.length - 1) {
                if (!_setClaimed(token, amount, wordPosition, bitsSet)) revert AlreadyClaimed();
            }

            bytes32 leaf = keccak256(abi.encodePacked(msg.sender, inputClaim.amount));
            bytes32 root = distributions[token].roots[inputClaim.batchNumber];

            if (!MerkleProof.verify(inputClaim.proof, root, leaf)) revert InvalidProof();

            inputTokens[inputClaim.tokenIndex].transfer(msg.sender, inputClaim.amount);
        }
    }

    function _setClaimed(IERC20 token, uint256 amount, uint256 wordPosition, uint256 newBits) private returns (bool) {
        uint256 currentWord = distributions[token].claims[msg.sender][wordPosition]; // bits
        if ((currentWord & newBits) != 0) return false;

        // update state
        distributions[token].claims[msg.sender][wordPosition] = currentWord | newBits;
        distributions[token].remaining -= amount;

        return true;
    }
}
