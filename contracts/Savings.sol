// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IStablecoin.sol';
import './interfaces/ISavings.sol';
import './utils/TrackerControl.sol';

contract Savings is ISavings, TrackerControl {
	uint256 public totalDeposit;
	uint256 public totalAllocate;
	uint256 public totalAllocateClaim;

	// ---------------------------------------------------------------------------------------

	event DepositFund(address indexed sender, uint256 value, uint256 total);

	// event AllocateFund
	// event AllocateFundClaim

	// ---------------------------------------------------------------------------------------

	constructor(
		IStablecoin _coin,
		string memory _name,
		uint32 _quorum,
		uint8 _days
	) TrackerControl(_coin, _name, _quorum, _days) {}

	// ---------------------------------------------------------------------------------------

	function declareDeposit(address from, uint256 value) public {
		coin.verifyOnlyCoin(msg.sender);
		totalDeposit += value;
		emit DepositFund(from, value, totalDeposit);
	}

	// claim interest via can activate
}
