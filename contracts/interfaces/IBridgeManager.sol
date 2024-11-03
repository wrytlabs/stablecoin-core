// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import '../Stablecoin.sol';
import '../utils/Errors.sol';

interface IBridgeManager is Errors {
	struct Guard {
		address collateral;
		uint256 mintable;
		uint256 reserve;
		uint256 rate;
		uint256 nextMintable;
		uint256 nextReserve;
		uint256 nextRate;
		uint256 canActivate;
	}

	struct Position {
		address collateral;
	}

	// View functions
	function CAN_ACTIVATE_DELAY() external view returns (uint256);

	function coin() external view returns (Stablecoin);

	function tokenCnt() external view returns (uint256);

	// function guards(address collateral) external view returns (Guard memory);

	// function positions(uint256 tokenId) external view returns (Position memory);

	function byCollateral(address collateral, uint256 index) external view returns (uint256);

	// State changing functions
	function proposeGuards(
		address collateral,
		uint256 newMintable,
		uint256 newReserve,
		uint256 newRate,
		address[] calldata helpers
	) external;

	function activateGuards(address collateral) external;

	function create(address to) external;
}
