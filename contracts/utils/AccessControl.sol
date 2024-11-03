// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IAccessControl.sol';

abstract contract AccessControl is IAccessControl {
	mapping(address => bool) public isMinter;
	mapping(address => uint256) public minterActivation;
	mapping(address => uint256) public minterExpiration;

	mapping(address => bool) public isMover;
	mapping(address => uint256) public moverActivation;
	mapping(address => uint256) public moverExpiration;

	// ---------------------------------------------------------------------------------------

	modifier _verifyOnlyCoin() {
		if (checkOnlyCoin(msg.sender) == false) revert NotCoin();
		_;
	}

	modifier _verifyMinter() {
		if (checkMinter(msg.sender) == false) revert NotMinter(msg.sender);
		_;
	}

	modifier _verifyMover() {
		if (checkMover(msg.sender) == false) revert NotMover(msg.sender);
		_;
	}

	modifier _verifyMinterMover() {
		if (checkMinter(msg.sender) == false) revert NotMinter(msg.sender);
		if (checkMover(msg.sender) == false) revert NotMover(msg.sender);
		_;
	}

	// ---------------------------------------------------------------------------------------

	function checkOnlyCoin(address toCheck) public view returns (bool) {
		if (toCheck != address(this)) return false;
		return true;
	}

	function checkMinter(address toCheck) public view returns (bool) {
		if (isMinter[toCheck] == false) return false;
		if (minterActivation[toCheck] == 0) return false;
		if (minterActivation[toCheck] > block.timestamp) return false;
		if (minterExpiration[toCheck] <= block.timestamp) return false;
		return true;
	}

	function checkMover(address toCheck) public view returns (bool) {
		if (isMover[toCheck] == false) return false;
		if (moverActivation[toCheck] == 0) return false;
		if (moverActivation[toCheck] > block.timestamp) return false;
		if (moverExpiration[toCheck] <= block.timestamp) return false;
		return true;
	}

	function checkMinterMover(address toCheck) public view returns (bool) {
		if (checkMinter(toCheck) == false) return false;
		if (checkMover(toCheck) == false) return false;
		return true;
	}

	// ---------------------------------------------------------------------------------------

	function verifyOnlyCoin(address toCheck) public view _verifyOnlyCoin {}

	function verifyMinter(address minter) public view _verifyMinter {}

	function verifyMover(address minter) public view _verifyMover {}

	function verifyMinterMover(address minter) public view _verifyMinterMover {}

	// ---------------------------------------------------------------------------------------
}
