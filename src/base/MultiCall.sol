// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "../interfaces/IMulticall.sol";

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract Multicall is IMulticall {

    /// @inheritdoc IMulticall
    function multicall(uint256 deadline, bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory)
    {
        if(block.timestamp > deadline) revert Deadline();
        return multicall(data);
    }

    /// @inheritdoc IMulticall
    function multicall(bytes32 previousBlockhash, bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory)
    {
        if(blockhash(block.number - 1) != previousBlockhash) revert BlockHash();
        return multicall(data);
    }

    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}
