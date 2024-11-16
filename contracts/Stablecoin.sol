// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './interfaces/IStablecoin.sol';

import './utils/AccessControl.sol';
import './Governance.sol';
import './Savings.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is IStablecoin, ERC20, AccessControl {
	using Math for uint256;
	using SafeERC20 for ERC20;

	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month
	uint256 public constant ACTIVATION_DURATION = 2 * 365 days; // 2 years
	uint256 public constant ACTIVATION_MULTIPLIER = 3; // extend 3x time served

	Governance public immutable votes;
	Savings public immutable savings;

	uint256 public totalInflow;
	uint256 public totalOutflow;
	uint256 public totalOutflowCovered;

	// ---------------------------------------------------------------------------------------
	event ProposeMinter(
		address indexed proposer,
		address indexed minter,
		string message,
		bool isMinter,
		uint256 activation,
		uint256 expiration
	);
	event ProposeMover(
		address indexed proposer,
		address indexed mover,
		string message,
		bool isMover,
		uint256 activation,
		uint256 expiration
	);
	event DeclareInflow(address indexed sender, uint256 value, uint256 total);
	event DeclareOutflow(address indexed sender, uint256 value, uint256 covered, uint256 total);

	// ---------------------------------------------------------------------------------------

	constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
		votes = new Governance(this, 'Votes', 20_000, 90);
		savings = new Savings(this, 'Savings', 0, 3);
	}

	function _setMinter(address to, string calldata message) public {
		if (totalSupply() > 0) revert NoChange();
		isMinter[to] = true;
		minterActivation[to] = block.timestamp;
		minterExpiration[to] = type(uint256).max;
		emit ProposeMinter(msg.sender, to, message, true, block.timestamp, type(uint256).max);
	}

	function _setMover(address to, string calldata message) public {
		if (totalSupply() > 0) revert NoChange();
		isMover[to] = true;
		moverActivation[to] = block.timestamp;
		moverExpiration[to] = type(uint256).max;
		emit ProposeMover(msg.sender, to, message, true, block.timestamp, type(uint256).max);
	}

	// ---------------------------------------------------------------------------------------
	// ERC20 modifications
	function _update(address from, address to, uint256 value) internal virtual override {
		// update voting power
		votes._update(from, to, value);

		// update interest claim
		savings._update(from, to, value);

		// update balance via super
		super._update(from, to, value);
	}

	function allowance(address owner, address spender) public view virtual override(ERC20, IERC20) returns (uint256) {
		if (checkMover(spender) == true) return type(uint256).max;
		return super.allowance(owner, spender);
	}

	// ---------------------------------------------------------------------------------------
	// TODO: move part of logic to AccessControl. do same for mover
	function proposeMinter(address minter, bool activate, string calldata message, address[] calldata helpers) public {
		votes.checkCanActivate(msg.sender, helpers);

		// extend expiration, if already passed
		if (activate && checkMinter(minter) == true) {
			uint256 duration = minterExpiration[minter] - minterActivation[minter]; // approved duration
			uint256 active = block.timestamp - minterActivation[minter]; // time active
			if (active * 2 <= duration) revert NotServed(); // serve more then 50% of your duration
			minterExpiration[minter] = block.timestamp + ACTIVATION_MULTIPLIER * active; // extend relative
		}
		// activate with delay or after expiration
		else if (activate && checkMinter(minter) == false) {
			isMinter[minter] = true;
			minterActivation[minter] = block.timestamp + CAN_ACTIVATE_DELAY;
			minterExpiration[minter] = block.timestamp + CAN_ACTIVATE_DELAY + ACTIVATION_DURATION;
		}
		// expire with delay
		else if (!activate && checkMinter(minter) == true) {
			minterExpiration[minter] = block.timestamp + CAN_ACTIVATE_DELAY;
		}
		// could revert a proposal
		else if (!activate && checkMinter(minter) == false) {
			minterExpiration[minter] = minterActivation[minter];
		}

		emit ProposeMinter(
			msg.sender,
			minter,
			message,
			isMinter[minter],
			minterActivation[minter],
			minterExpiration[minter]
		);
	}

	function mint(address account, uint256 value) public _verifyMinter {
		_mint(account, value);
	}

	// ---------------------------------------------------------------------------------------

	function declareInflow(address from, uint256 value) public _verifyMover {
		if (value == 0) revert NoChange(); // @dev: might change to pass without reverting

		_transfer(from, address(savings), value);
		savings.declareDeposit(from, value);

		totalInflow += value;
		emit DeclareInflow(from, value, totalInflow);
	}

	function declareOutflow(address to, uint256 value) public _verifyMinter {
		if (value == 0) revert NoChange(); // @dev: might change to pass without reverting

		uint256 saved = balanceOf(address(savings));

		if (saved >= value) {
			_transfer(address(savings), to, value);
		} else {
			_transfer(address(savings), to, saved);
			_mint(to, value - saved);
		}

		totalOutflow += value;
		totalOutflowCovered += saved;
		emit DeclareOutflow(to, value, saved, totalOutflow);
	}
}
