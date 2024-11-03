// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './interfaces/IStablecoin.sol';
import './utils/Errors.sol';

// TODO: other ERC...
contract BridgeManager is ERC721, Errors {
	using Math for uint256;

	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month

	IStablecoin public immutable coin;
	Governance public immutable votes;

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

	uint256 public tokenCnt;

	mapping(address collateral => Guard) public guards;
	mapping(uint256 tokenId => Position) public positions;
	mapping(address collateral => uint256[]) public byCollateral;

	// ---------------------------------------------------------------------------------------

	event ProposeGuard(address indexed proposer, address collateral, uint256 reserve, uint256 mintable, uint256 rate);
	event ActivateGuard(address indexed sender, address collateral, uint256 reserve, uint256 mintable, uint256 rate);

	// ---------------------------------------------------------------------------------------

	constructor(IStablecoin _coin, string memory name, string memory symbol) ERC721(name, symbol) {
		coin = _coin;
		votes = IGovernance(coin.votes);
	}

	function _setGuard(address collateral, uint256 newMintable, uint256 newReserve, uint256 newRate) public {
		if (tokenCnt > 0) revert NoChange();
		guards[collateral] = Guard(collateral, newMintable, newReserve, newRate, newMintable, newRate, 0);
		emit ActivateGuard(msg.sender, collateral, newMintable, newReserve, newRate);
	}

	// ---------------------------------------------------------------------------------------

	function proposeGuards(
		address collateral,
		uint256 newMintable,
		uint256 newReserve,
		uint256 newRate,
		address[] calldata helpers
	) public {
		votes.verifyCanActivate(msg.sender, helpers);

		Guard memory guard = guards[collateral];
		if (guard.mintable == newMintable || guard.reserve == newReserve || guard.rate == newRate) revert NoChange();

		guard.nextMintable = newMintable;
		guard.nextReserve = newReserve;
		guard.nextRate = newRate;
		guard.nextCanActivate = block.timestamp + CAN_ACTIVATE_DELAY;

		guards[collateral] = guard;

		emit ProposeGuard(msg.sender, collateral, newMintable, newReserve, newRate);
	}

	function activateGuards(address collateral) public {
		Guard memory guard = guards[collateral];
		if (guard.canActivate < block.timestamp) revert NotActive();
		if (guard.mintable == guard.nextMintable && guard.reserve == guard.nextReserve && guard.rate == guard.nextRate)
			revert NoChange();

		guard.mintable = guard.nextMint;
		guard.rate = guard.nextRate;

		guards[collateral] = guard;

		emit ActivateGuard(msg.sender, collateral, guard.nextMint, guard.nextReserve, guard.nextRate);
	}

	// ---------------------------------------------------------------------------------------
	function create(address to) public {
		tokenCnt += 1;
		_mint(to, tokenCnt);
		// emit
	}
}
