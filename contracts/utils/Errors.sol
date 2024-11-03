// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Errors {
	// Access Control Errors
	error NotCoin();
	error NotMinter(address account);
	error NotMover(address account);
	error MinterExpired(address caller);
	error MoverExpired(address caller);

	// Tracker Control Errors
	error NotPassedDuration();
	error NotQualified();
	error NotAvailable();

	// Stablecoin Errors
	error NoChange();
	error NotActive();
	error NotServed();
}
