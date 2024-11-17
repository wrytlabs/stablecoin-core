// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../../interfaces/IErrors.sol';

interface IAccessControl is IErrors {
	// Constant
	function CAN_ACTIVATE_DELAY() external view returns (uint256);

	function ACTIVATION_DURATION() external view returns (uint256);

	function ACTIVATION_MULTIPLIER() external view returns (uint256);

	// View functions
	function isModule(address) external view returns (bool);

	function moduleActivation(address) external view returns (uint256);

	function moduleExpiration(address) external view returns (uint256);

	// Check functions
	function checkOnlyCoin(address toCheck) external view returns (bool);

	function checkModule(address toCheck) external view returns (bool);

	// Verify functions
	function verifyOnlyCoin(address toCheck) external view;

	function verifyModule(address module) external view;

	// ...
}
