// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IGovernance.sol';
import './utils/TrackerControl.sol';

contract Governance is IGovernance, TrackerControl {
	constructor(
		IStablecoin _coin,
		string memory _name,
		uint32 _quorum,
		uint8 _days
	) TrackerControl(_coin, _name, _quorum, _days) {}

	// ---------------------------------------------------------------------------------------
}
