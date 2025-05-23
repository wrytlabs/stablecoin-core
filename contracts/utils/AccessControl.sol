// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IAccessControl.sol';

abstract contract AccessControl is IAccessControl {
	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month
	uint256 public constant ACTIVATION_DURATION = 365 days; // 1 years
	uint256 public constant ACTIVATION_MULTIPLIER = 2; // extend 2x time served

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
		verifyOnlyCoin(msg.sender);
		_;
	}

	function checkOnlyCoin(address account) public view returns (bool) {
		if (account != address(this)) return false;
		return true;
	}

	function verifyOnlyCoin(address account) public view {
		if (checkOnlyCoin(account) == false) revert NotCoin(account);
	}

	// ---------------------------------------------------------------------------------------

	modifier _verifyModule() {
		verifyModule(msg.sender);
		_;
	}

	function checkModule(address module) public view returns (bool) {
		if (isModule[module] == false) return false; // not active or default
		if (moduleActivation[module] == 0) return false; // default
		if (moduleActivation[module] > block.timestamp) return false; // must be in the past
		if (moduleExpiration[module] <= block.timestamp) return false; // must be in the future
		return true;
	}

	function verifyModule(address module) public view {
		if (checkModule(module) == false) revert NotModule(module);
	}

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
			moduleActivation[module] = 0;
			moduleExpiration[module] = 0;
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
