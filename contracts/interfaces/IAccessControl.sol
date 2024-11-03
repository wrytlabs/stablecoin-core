// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccessControl {
	function isMinter(address) external view returns (bool);

	function isMover(address) external view returns (bool);

	function minterExpiration(address) external view returns (uint256);

	function moverExpiration(address) external view returns (uint256);

	function checkMinter(address minter) external view returns (bool);

	function checkMover(address mover) external view returns (bool);

	function checkMinterMover(address toCheck) external view returns (bool);

	function verifyMinter(address minter) external;

	function verifyMover(address mover) external;

	function verifyMinterMover(address minter) external;
}
