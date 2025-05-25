// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface for the Ownable access control contract.
 */
interface IOwnable {
	/// @dev Emitted when ownership is transferred from one address to another.
	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/// @dev Error thrown when a non-owner tries to perform an owner-only operation.
	error OwnableUnauthorizedAccount(address account);

	/// @dev Error thrown when trying to assign an invalid owner (e.g., address(0)).
	error OwnableInvalidOwner(address owner);

	/// @notice Returns the current owner of the contract.
	function owner() external view returns (address);

	/// @notice Transfers ownership to a new address.
	/// @param newOwner The address of the new owner.
	function transferOwnership(address newOwner) external;

	/// @notice Renounces ownership of the contract (leaves it without an owner).
	function renounceOwnership() external;
}
