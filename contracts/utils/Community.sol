// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/ICommunity.sol';
import '../Stablecoin.sol';

contract Community is ICommunity {
	Stablecoin public immutable coin;

	uint256 public totalDeposit;
	uint256 public totalAllocate;
	uint256 public totalAllocateClaim;

	// ---------------------------------------------------------------------------------------

	event DepositFund(address indexed sender, uint256 value, uint256 total);

	// event AllocateFund
	// event AllocateFundClaim

	// ---------------------------------------------------------------------------------------

	constructor(Stablecoin _coin) {
		coin = _coin;
	}

	function declareDeposit(address from, uint256 value) public {
		coin.verifyOnlyCoin(msg.sender);
		totalDeposit += value;
		emit DepositFund(from, value, totalDeposit);
	}

	// claim interests --> could be used to cover operational costs via earnings

	// claim funds --> could be used to cover further major upgrades to the protocol
}
