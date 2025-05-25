// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnable} from './IOwnable.sol';

/**
 * @dev Interface for the Ownable2Step access control contract.
 */
interface IOwnable2Step is IOwnable {
	/// @dev Emitted when a new ownership transfer is initiated.
	event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

	/// @notice Returns the address of the pending owner.
	function pendingOwner() external view returns (address);

	/// @notice Called by the pending owner to accept ownership.
	function acceptOwnership() external;
}
