// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract AccessControl {
	mapping(address => bool) public isMinter;
	mapping(address => bool) public isMover;

	error NotMinter(address caller);
	error NotMover(address caller);

	modifier verifyMinter() {
		if (isMinter[msg.sender] == false) revert NotMinter(msg.sender);
		_;
	}

	modifier verifyMover() {
		if (isMover[msg.sender] == false) revert NotMover(msg.sender);
		_;
	}

	modifier verifyMinterMover() {
		if (isMinter[msg.sender] == false) revert NotMinter(msg.sender);
		if (isMover[msg.sender] == false) revert NotMover(msg.sender);
		_;
	}

	function checkMinter(address minter) public verifyMinter {}

	function checkMover(address minter) public verifyMover {}

	function checkMinterMover(address minter) public verifyMinterMover {}
}
