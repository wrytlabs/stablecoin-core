// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ITrackerControl {
	error NotCoin();
	error NotPassedDuration();
	error NotQualified();
	error NotAvailable();

	function QUORUM() external view returns (uint32);

	function MIN_HOLDING_DURATION() external view returns (uint256);

	function coin() external view returns (IERC20);

	function name() external view returns (string memory);

	function totalTracksAtAnchor() external view returns (uint256);

	function totalTracksAnchorTime() external view returns (uint256);

	function delegates(address owner) external view returns (address);

	function checkOnlyCoin(address toCheck) external view returns (bool);

	function verifyOnlyCoin(address toCheck) external view;

	function totalTracks() external view returns (uint256);

	function tracks(address holder) external view returns (uint256);

	function relativeTracks(address holder) external view returns (uint256);

	function holdingDuration(address holder) external view returns (uint256);

	function checkHoldingDuration(address holder) external view returns (bool);

	function verifyHoldingDuration(address holder) external view;

	function checkCanActivate(address holder, address[] calldata helpers) external view returns (bool);

	function verifyCanActivate(address holder, address[] calldata helpers) external view;

	function tracksDelegated(address sender, address[] calldata helpers) external view returns (uint256);

	function reduceTracks(address[] calldata targets, uint256 tracksToDestroy) external;
}
