// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract AccessControl {
	mapping(address => bool) public isMinter;
	mapping(address => uint256) public minterExpiration;

	mapping(address => bool) public isMover;
	mapping(address => uint256) public moverExpiration;

	// ---------------------------------------------------------------------------------------

	error NotMinter(address caller);
	error MinterExpired(address caller);

	error NotMover(address caller);
	error MoverExpired(address caller);

	// ---------------------------------------------------------------------------------------

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

	function checkMinter(address minter) public view returns (bool) {
		if (isMinter[minter] == false) return false;
		if (minterExpiration[minter] < block.timestamp) return false;
		return true;
	}

	function checkMover(address mover) public view returns (bool) {
		if (isMover[mover] == false) return false;
		if (moverExpiration[mover] < block.timestamp) return false;
		return true;
	}

	function checkMinterMover(address toCheck) public view returns (bool) {
		if (checkMinter(toCheck) == false) return false;
		if (checkMover(toCheck) == false) return false;
		return true;
	}

	// ---------------------------------------------------------------------------------------

	function verifyMinter(address minter) public _verifyMinter {}

	function verifyMover(address minter) public _verifyMover {}

	function verifyMinterMover(address minter) public _verifyMinterMover {}
}
