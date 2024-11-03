// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './interfaces/IStablecoin.sol';

// TODO: other ERC...
contract BridgeManager is ERC721 {
	using Math for uint256;

	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month

	IStablecoin public immutable coin;
	Governance public immutable votes;

	struct Guard {
		address collateral;
		uint256 mint;
		uint256 rate;
		uint256 nextMint;
		uint256 nextRate;
		uint256 canActivate;
	}

	struct Position {
		address collateral;
	}

	uint256 public tokenCnt;
	mapping(address collateral => Guard) public guards;
	mapping(uint256 tokenId => Position) public positions;

	// ---------------------------------------------------------------------------------------

	event ProposeGuard(address indexed proposer, address collateral, uint256 mint, uint256 rate);
	event ActivateGuard(address indexed sender, address collateral, uint256 mint, uint256 rate);

	// ---------------------------------------------------------------------------------------

	constructor(IStablecoin _coin, string memory name, string memory symbol) ERC721(name, symbol) {
		coin = _coin;
		votes = IGovernance(coin.votes);
	}

	function _setGuard(address collateral, uint256 newMint, uint256 newRate) public {
		if (tokenCnt > 0) revert NoChange();
		guards[collateral] = Guard(collateral, newMint, newRate, newMint, newRate, 0);
		emit ActivateGuard(msg.sender, collateral, newMint, newRate);
	}

	// ---------------------------------------------------------------------------------------

	function proposeGuards(address collateral, uint256 newMint, uint256 newRate, address[] calldata helpers) public {
		votes.verifyCanActivate(msg.sender, helpers);

		Guard memory guard = guards[collateral];
		if (guard.mint == newMint || guard.rate == newRate) revert NoChange();

		guard.nextMint = newMint;
		guard.nextRate = newRate;
		guard.nextCanActivate = block.timestamp + CAN_ACTIVATE_DELAY;

		guards[collateral] = guard;

		emit ProposeGuard(msg.sender, collateral, newMint, newRate);
	}

	function activateGuards(address collateral) public {
		Guard memory guard = guards[collateral];

		if (guard.canActivate < block.timestamp) revert NotActive();
		if (guard.mint == guard.nextMint && guard.rate == guard.nextRate) revert NoChange();

		guard.mint = guard.nextMint;
		guard.rate = guard.nextRate;

		guards[collateral] = guard;

		emit ActivateGuard(msg.sender, collateral, guard.nextMint, guard.nextRate);
	}

	// ---------------------------------------------------------------------------------------
	function mint(address to) public {
		tokenCnt += 1;
		_mint(to, tokenCnt);
		// emit
	}
}
