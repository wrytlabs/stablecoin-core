// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {
	// Access Control Errors
	error NotCoin(address account);
	error NotModule(address module);
	error ModuleExpired(address module);

	// Tracker Control Errors
	error NotPassedDuration(address, uint256, uint256);
	error NotPassedQuorum(address, uint256, uint256);
	error NotQualified();
	error NotAvailable();
	error InsufficientBalance(address, uint256, uint256);

	// Stablecoin Errors
	error NoChange();
	error NotActive();
	error NotServed();
}
