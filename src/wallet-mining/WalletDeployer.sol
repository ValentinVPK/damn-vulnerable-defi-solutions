// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @notice A contract that allows deployers of Gnosis Safe wallets to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of a Safe factory and copy on this chain
    // SafeProxyFactory (deploy) -> SafeProxy (points to) -> Safe
    SafeProxyFactory public immutable cook; // @audit-info - this is the address of the contract that creates the proxy for the Safe wallet
    address public immutable cpy; // @audit-info - this is the address of the Safe implementation

    uint256 public constant pay = 1 ether; // @audit-info - the amount of tokens that the deployer will receive for deploying a Safe wallet
    address public immutable chief; // @audit-info - the address of the deployer
    address public immutable gem; // @audit-info - the address of the DVT token

    address public mom; // @audit-info - the address of the AuthorizerUpgradeable contract
    address public hat;

    error Boom();

    constructor(address _gem, address _cook, address _cpy, address _chief) {
        gem = _gem; // Set to DVT token
        cook = SafeProxyFactory(_cook); // Set to SafeProxyFactory
        cpy = _cpy; // Set to Safe singleton copy
        chief = _chief; // Set to the "deployer" address
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     * @dev The authorizer contract can be set only by deployer, can be set only once and cannot be set to 0 address
     */
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
    }

    /**
     * @notice Allows the caller to deploy a new Safe account and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment
     */
    function drop(address aim, bytes memory wat, uint256 num) external returns (bool) {
        if (mom != address(0) && !can(msg.sender, aim)) {
            return false;
        }

        if (address(cook.createProxyWithNonce(cpy, wat, num)) != aim) {
            return false;
        }

        if (IERC20(gem).balanceOf(address(this)) >= pay) {
            IERC20(gem).transfer(msg.sender, pay);
        }
        return true;
    }

    // @audit-issue - check if this function is correct
    function can(address u, address a) public view returns (bool y) {
        assembly {
            let m := sload(0) // Loads the authorizer contract from storage
            if iszero(extcodesize(m)) { stop() } // Checks if the authorizer contract is deployed
            let p := mload(0x40) // Loads the pointer to the free memory location
            mstore(0x40, add(p, 0x44)) // Update free memory pointer (reserve 0x44 bytes)
            mstore(p, shl(0xe0, 0x4538c4eb)) // Store function selector for the can(address, address) function in the AuthorizerUpgradeable contract
            mstore(add(p, 0x04), u) // Store the address of the msg.sender in the free memory location
            mstore(add(p, 0x24), a) // Store the address of the aim in the free memory location
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { stop() }
            y := mload(p)
        }
    }
}
