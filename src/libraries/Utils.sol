// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

library Utils {
    error ToAddressOverflow();
    error ToAddressOutOfBounds();

    function _isContract(address _token) internal view {
        // solhint-disable-next-line
        assembly {
            // If address contains no code - revert (substitues address zero check)
            if iszero(extcodesize(_token)) { revert(0, 0) }
        }
    }

    function _toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        if (_start + 20 < _start) revert ToAddressOverflow();
        if (_bytes.length < _start + 20) revert ToAddressOutOfBounds();
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }
}
