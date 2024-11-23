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
	function checkOnlyCoin(address account) external view returns (bool);

	function verifyOnlyCoin(address account) external view;

	// Verify functions
	function verifyModule(address module) external view;

	function checkModule(address module) external view returns (bool);

	// ...
}
