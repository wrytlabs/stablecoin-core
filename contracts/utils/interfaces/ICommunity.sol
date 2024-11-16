// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../Stablecoin.sol';

interface ICommunity {
	// View functions
	function coin() external view returns (Stablecoin);

	function totalDeposit() external view returns (uint256);

	function totalAllocate() external view returns (uint256);

	function totalAllocateClaim() external view returns (uint256);

	// State changing functions
	function declareDeposit(address from, uint256 value) external;
}
