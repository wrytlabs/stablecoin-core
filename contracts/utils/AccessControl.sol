// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IAccessControl.sol';

abstract contract AccessControl is IAccessControl {
	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month
	uint256 public constant ACTIVATION_DURATION = 2 * 365 days; // 2 years
	uint256 public constant ACTIVATION_MULTIPLIER = 3; // extend 3x time served

	mapping(address => bool) public isModule;
	mapping(address => uint256) public moduleActivation;
	mapping(address => uint256) public moduleExpiration;

	// ---------------------------------------------------------------------------------------

	event ModuleUpdated(
		address indexed proposer,
		address indexed module,
		string message,
		bool isModule,
		uint256 activation,
		uint256 expiration
	);

	// ---------------------------------------------------------------------------------------

	modifier _verifyOnlyCoin() {
		if (checkOnlyCoin(msg.sender) == false) revert NotCoin();
		_;
	}

	modifier _verifyModule() {
		if (checkModule(msg.sender) == false) revert NotModule(msg.sender);
		_;
	}

	// ---------------------------------------------------------------------------------------

	function checkOnlyCoin(address toCheck) public view returns (bool) {
		if (toCheck != address(this)) return false;
		return true;
	}

	function checkModule(address toCheck) public view returns (bool) {
		if (isModule[toCheck] == false) return false; // not active or default
		if (moduleActivation[toCheck] == 0) return false; // default
		if (moduleActivation[toCheck] > block.timestamp) return false; // must be in the past
		if (moduleExpiration[toCheck] <= block.timestamp) return false; // must be in the future
		return true;
	}

	// ---------------------------------------------------------------------------------------

	function verifyOnlyCoin(address toCheck) public view _verifyOnlyCoin {}

	function verifyModule(address module) public view _verifyModule {}

	// ---------------------------------------------------------------------------------------

	function _configModule(address module, bool activate, string calldata message) internal {
		// extend expiration, if already passed
		if (activate && checkModule(module) == true) {
			uint256 duration = moduleExpiration[module] - moduleActivation[module]; // approved duration
			uint256 active = block.timestamp - moduleActivation[module]; // time active
			if (active * 2 <= duration) revert NotServed(); // serve more then 50% of your duration
			moduleExpiration[module] = block.timestamp + ACTIVATION_MULTIPLIER * active; // extend relative
		}
		// activate with delay or after expiration
		else if (activate && checkModule(module) == false) {
			isModule[module] = true;
			moduleActivation[module] = block.timestamp + CAN_ACTIVATE_DELAY;
			moduleExpiration[module] = block.timestamp + CAN_ACTIVATE_DELAY + ACTIVATION_DURATION;
		}
		// expire with delay
		else if (!activate && checkModule(module) == true) {
			moduleExpiration[module] = block.timestamp + CAN_ACTIVATE_DELAY;
		}
		// could revert a proposal
		else if (!activate && checkModule(module) == false) {
			moduleExpiration[module] = moduleActivation[module];
		}

		emit ModuleUpdated(
			msg.sender,
			module,
			message,
			isModule[module],
			moduleActivation[module],
			moduleExpiration[module]
		);
	}
}
