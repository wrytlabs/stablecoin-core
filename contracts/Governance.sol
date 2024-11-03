// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './utils/TrackerControl.sol';

contract Governance is TrackerControl {
	uint256 public totalDeposit;
	uint256 public totalAllocate;
	uint256 public totalAllocateClaim;

	// ---------------------------------------------------------------------------------------

	event DepositFund(address indexed sender, uint256 value, uint256 total);

	// event AllocateFund
	// event AllocateFundClaim

	// ---------------------------------------------------------------------------------------

	constructor(
		IERC20 _coin,
		string memory _name,
		uint32 _quorum,
		uint8 _days
	) TrackerControl(_coin, _name, _quorum, _days) {}

	// ---------------------------------------------------------------------------------------

	function declareDeposit(address from, uint256 value) public _verifyOnlyCoin {
		totalDeposit += value;
		emit DepositFund(from, value, totalDeposit);
	}

	// claim interests --> could be used to cover operational costs via earnings

	// claim funds --> could be used to cover further major upgrades to the protocol
}
