// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernance {
	function totalTracks() external view returns (uint256);

	function tracks(address holder) external view returns (uint256);

	function relativeTracks(address holder) external view returns (uint256);

	function holdingDuration(address holder) external view returns (uint256);

	function verifyHoldingDuration(address holder) external view returns (bool);

	function checkHoldingDuration(address holder) external view;

	function verifyCanActivate(address holder, address[] calldata helpers) external view returns (bool);

	function checkCanActivate(address holder, address[] calldata helpers) external view;

	function tracksDelegated(address sender, address[] calldata helpers) external view returns (uint256);

	function delegates(address owner) external view returns (address);
}
