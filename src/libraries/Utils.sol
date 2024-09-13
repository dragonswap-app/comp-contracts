// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

library Utils {
    function _isContract(address _token) internal view {
        // solhint-disable-next-line
        assembly {
            // If address contains no code - revert (substitues address zero check)
            if iszero(extcodesize(_token)) { revert(0, 0) }
        }
    }
}
