// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ICompetition} from "./interfaces/ICompetition.sol";

contract Factory is Ownable2Step {
    /// @dev Flag for the competition instances deployed by this factory instance.
    mapping(address => bool) public isDeployedThroughFactory;
    /// @dev Array of all the competition deployments.
    address[] public deployments;
    /// @dev Competition contract implementation.
    address public implementation;

    // Events
    event Deployed(address indexed instance, address indexed implementation);
    event ImplementationSet(address indexed implementation);

    // Errors
    error CloneCreationFailed();
    error ImplementationNotSet();
    error ImplementationAlreadySet();
    error InvalidIndexRange();

    constructor(address _owner) Ownable(_owner) {}

    /**
     * @dev Function to set new competition contract implementation.
     */
    function setImplementation(address _implementation) external onlyOwner {
        // Require that implementation is different from current one.
        if (implementation == _implementation) {
            revert ImplementationAlreadySet();
        }
        // Set new implementation.
        implementation = _implementation;
        // Emit relevant event.
        emit ImplementationSet(_implementation);
    }

    function deploy(
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _router,
        address[] memory _stableCoins,
        address[] memory _swapTokens
    ) external onlyOwner {
        address impl = implementation;
        // Require that implementation is set.
        if (impl == address(0)) {
            revert ImplementationNotSet();
        }
        address instance;
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, impl)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, impl), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        // Require that a clone instance is made successfully.
        if (instance == address(0)) {
            revert CloneCreationFailed();
        }

        // Mark the deployment as created through factory.
        isDeployedThroughFactory[instance] = true;
        // Add the deployment to the deployments array.
        deployments.push(instance);

        // Initialize the instance.
        ICompetition(instance).initialize(owner(), _startTimestamp, _endTimestamp, _router, _stableCoins, _swapTokens);
        // Emit event.
        emit Deployed(instance, impl);
    }

    /**
     * @dev Function to retrieve total number of deployments made by this factory.
     */
    function noOfDeployments() public view returns (uint256 count) {
        count = deployments.length;
    }

    /**
     * @dev Function to retrieve the address of the latest deployment made by this factory.
     * @return latestDeployment is the latest deployment address.
     */
    function getLatestDeployment() external view returns (address latestDeployment) {
        uint256 _noOfDeployments = noOfDeployments();
        if (_noOfDeployments > 0) latestDeployment = deployments[_noOfDeployments - 1];
        // Return zero address if no deployments were made.
    }

    /**
     * @dev Function to retrieve all deployments between indexes.
     * @param startIndex First index.
     * @param endIndex Last index.
     * @return _deployments All deployments between provided indexes, inclusive.
     */
    function getAllDeployments(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory _deployments)
    {
        // Require valid index input.
        if (endIndex < startIndex || endIndex >= deployments.length) {
            revert InvalidIndexRange();
        }
        // Initialize a new array.
        _deployments = new address[](endIndex - startIndex + 1);
        uint256 index = 0;
        // Fill the array with the deployment addresses.
        for (uint256 i = startIndex; i <= endIndex; i++) {
            _deployments[index] = deployments[i];
            index++;
        }
    }
}
