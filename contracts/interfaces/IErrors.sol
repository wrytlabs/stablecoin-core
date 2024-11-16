// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {
	// Access Control Errors
	error NotCoin();
	error NotModule(address account);
	error ModuleExpired(address caller);

	// Tracker Control Errors
	error NotPassedDuration();
	error NotQualified();
	error NotAvailable();

	// Stablecoin Errors
	error NoChange();
	error NotActive();
	error NotServed();
}
