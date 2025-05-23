// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../../interfaces/IErrors.sol';

interface ITrackerControl is IErrors {
	// View functions
	function CAN_ACTIVATE_QUORUM() external view returns (uint32);

	function CAN_ACTIVATE_DELAY() external view returns (uint256);

	function name() external view returns (string memory);

	function totalBalance() external view returns (uint256);

	function totalTracksAtAnchor() external view returns (uint256);

	function totalTracksAnchorTime() external view returns (uint256);

	function trackerBalance(address holder) external view returns (uint256);

	function trackerAnchor(address holder) external view returns (uint64);

	function trackerDelegate(address holder) external view returns (address);

	// Core tracking functions
	function totalTracks() external view returns (uint256);

	function tracksOf(address holder) external view returns (uint256);

	function delegateInfo(address holder) external view returns (address, uint256);

	function delegate(address to) external;

	function _update(address from, address to, uint256 amount) external;

	function reduceOwnTracks(uint value) external returns (uint256);

	function reduceTargetTracks(address target, uint256 value) external returns (uint256);

	// Coin check
	function coin() external view returns (IERC20);

	function checkOnlyCoin(address toCheck) external view returns (bool);

	function verifyOnlyCoin(address toCheck) external view;

	// Duration checks
	function holdingDuration(address holder) external view returns (uint256);

	function checkHoldingDuration(address holder) external view returns (bool);

	function verifyHoldingDuration(address holder) external view;

	// Quorum checks
	function quorum(address holder) external view returns (uint256);

	function checkQuorum(address holder) external view returns (bool);

	function verifyQuorum(address holder) external view;

	// Activation checks
	function checkCanActivate(address holder) external view returns (bool);

	function verifyCanActivate(address holder) external view;
}
