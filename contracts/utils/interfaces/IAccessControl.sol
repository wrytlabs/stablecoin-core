// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccessControl {
	// Custom errors
	error NotCoin();
	error NotMinter(address caller);
	error MinterExpired(address caller);
	error NotMover(address caller);
	error MoverExpired(address caller);

	// View functions
	function isMinter(address) external view returns (bool);

	function minterActivation(address) external view returns (uint256);

	function isMover(address) external view returns (bool);

	function moverActivation(address) external view returns (uint256);

	// Check functions
	function checkOnlyCoin(address toCheck) external view returns (bool);

	function checkMinter(address toCheck) external view returns (bool);

	function checkMover(address toCheck) external view returns (bool);

	function checkMinterMover(address toCheck) external view returns (bool);

	// Verify functions
	function verifyOnlyCoin(address toCheck) external view;

	function verifyMinter(address minter) external view;

	function verifyMover(address minter) external view;

	function verifyMinterMover(address minter) external view;
}
