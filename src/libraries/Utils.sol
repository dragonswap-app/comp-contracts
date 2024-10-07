// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

library Utils {
    // Errors
    error NotAContract();
    error ToAddressOverflow();
    error ToAddressOutOfBounds();

    /**
     * @dev Function to check if there is code present at the specified address.
     */
    function _isContract(address _addr) internal view {
        // If address contains no code - revert (also substitutes address zero check).
        if (address(_addr).code.length == 0) revert NotAContract();
    }

    /**
     * @dev Function to retrieve an address from a byte string.
     * @param _bytes is the byte string to retrieve the address from.
     * @param _start represents the number of a byte at which the address starts.
     */
    function _toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address addr) {
        if (_start > type(uint256).max - 20) revert ToAddressOverflow();
        if (_bytes.length < _start + 20) revert ToAddressOutOfBounds();
        assembly {
            addr := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }
    }
}
