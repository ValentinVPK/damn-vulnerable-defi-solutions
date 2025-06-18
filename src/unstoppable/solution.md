# Unstoppable

The different external contract and concepts used in this level include:

## ERC-4626

- https://www.quicknode.com/guides/ethereum-development/smart-contracts/how-to-use-erc-4626-with-your-smart-contract
- https://rivanorth.com/blog/erc-4626-vulnerabilities-and-how-to-avoid-them-in-your-project
- https://medium.com/coinmonks/another-look-at-the-security-of-erc4626-vaults-9901618d0923

## ReentrancyGuard

- https://medium.com/@mayankchhipa007/openzeppelin-reentrancy-guard-a-quickstart-guide-7f5e41ee388f
- https://www.cyfrin.io/blog/what-is-a-reentrancy-attack-solidity-smart-contracts
- `nonReadReentrant` - used only for view and pure functions which only read the state, more gas efficient than nonReentrant; `nonReentrant` is used for functions which also modify the state

## Ownership

- https://docs.openzeppelin.com/contracts/4.x/access-control

## Pausable

- https://docs.openzeppelin.com/contracts/2.x/api/lifecycle

## ERC-3156 Flash loans

- https://www.rareskills.io/post/erc-3156

## Solution

- We had to `DoS` the contract which issues the flash loans
- There was the following if check:
  ```solidity
  if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance()
  ```
- If we added `1 wei` to the vault contract with `token.transfer()` that would render this check to always return false and prohibit anyone from using the vault contract to get a flash loan:
  ```solidity
  token.transfer(address(vault), 1);
  ```
