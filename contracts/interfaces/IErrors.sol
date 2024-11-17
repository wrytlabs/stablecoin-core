// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {
	// Access Control Errors
	error NotCoin();
	error NotModule(address account);
	error ModuleExpired(address caller);

	// Tracker Control Errors
	error NotPassedDuration(uint256);
	error NotQualified();
	error NotAvailable();
	error InsufficientBalance(address, uint256, uint256);

	// Stablecoin Errors
	error NoChange();
	error NotActive();
	error NotServed();
}
