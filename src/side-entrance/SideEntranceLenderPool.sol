// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Балансът на играча е 1 ETH
interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

// Балансът на контракта е 1000 ETH
contract SideEntranceLenderPool {
    mapping(address => uint256) public balances;

    error RepayFailed();

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address indexed who, uint256 amount);

    // @audit-info понеже работим с ETH, мисля че тук всичко е точно
    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        //@audit-issue тук имаме reentrancy - ще видя как да го експлоитирам по-късно
        uint256 amount = balances[msg.sender];

        delete balances[msg.sender];
        emit Withdraw(msg.sender, amount);

        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance; // 1000 ETH

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}(); // тук ще извикаме execute() на контракта, който е направил транзакцията

        if (address(this).balance < balanceBefore) {
            revert RepayFailed();
        }
    }

    // Атаката е следната:
    // 1. С атакуващ контракт, ще извикам flashLoan() с amount 1000 ETH
    // 2. В execute() на контракта ще извикам deposit() с amount 1000 ETH
    // 3. В атакуващия контракт ще извикам withdraw() с amount 1000 ETH
    // 4. Ще изивкам transfer към recovery адреса
}
