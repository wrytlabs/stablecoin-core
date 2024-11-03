// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../utils/interfaces/ITrackerControl.sol';

interface ISavings is ITrackerControl {
	// State view functions
	function totalDeposit() external view returns (uint256);

	function totalAllocate() external view returns (uint256);

	function totalAllocateClaim() external view returns (uint256);

	// Core functions
	function declareDeposit(address from, uint256 value) external;
}
