// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './utils/TrackerControl.sol';

contract Governance is TrackerControl {
	constructor(
		IERC20 _coin,
		string memory _name,
		uint32 _quorum,
		uint8 _days
	) TrackerControl(_coin, _name, _quorum, _days) {}
}
