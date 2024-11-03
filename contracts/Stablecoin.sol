// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './interfaces/IStablecoin.sol';

import './utils/interfaces/IAccessControl.sol';
import './utils/AccessControl.sol';

import './Governance.sol';
import './Savings.sol';
import './Community.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is IStablecoin, ERC20, AccessControl {
	using Math for uint256;
	using SafeERC20 for ERC20;

	uint256 public constant CAN_ACTIVATE_DELAY = 30 days; // 1 month
	uint256 public constant ACTIVATION_DURATION = 2 * 365 days; // 2 years
	uint256 public constant ACTIVATION_MULTIPLIER = 3; // extend 3x time served

	Governance public immutable votes;
	Savings public immutable savings;
	Community public immutable funds;

	uint256 public totalProfit;
	uint256 public totalLoss;

	uint256 public fundDistribution = 5_000; // 5% in PPM
	uint256 public fundMinSize = 1_000 ether;
	uint256 public nextFundDistribution;
	uint256 public nextFundMinSize;
	uint256 public nextFundCanActivate;

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
	event ProposeFund(address indexed proposer, uint256 distribution, uint256 minSize, uint256 canActivate);
	event ActivateFund(address indexed sender, uint256 distribution, uint256 minSize);
	event DeclareProfit(address indexed sender, uint256 value, uint256 total);
	event DeclareLoss(address indexed sender, uint256 value, uint256 total);

	// ---------------------------------------------------------------------------------------

	constructor() ERC20('Stablecoin', 'STBL') {
		votes = new Governance(this, 'Votes', 20_000, 90);
		savings = new Savings(this, 'Savings', 0, 3);
		funds = new Community(this);
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

	function proposeFundDistribution(uint256 distribution, uint256 size, address[] calldata helpers) public {
		votes.verifyCanActivate(msg.sender, helpers);

		if (fundDistribution == distribution || fundMinSize == size) revert NoChange();

		nextFundDistribution = distribution;
		nextFundMinSize = size;
		nextFundCanActivate = block.timestamp + CAN_ACTIVATE_DELAY;

		emit ProposeFund(msg.sender, distribution, size, nextFundCanActivate);
	}

	function activateFundDistribution() public {
		if (nextFundCanActivate < block.timestamp) revert NotActive();
		if (fundDistribution == nextFundDistribution && fundMinSize == nextFundMinSize) revert NoChange();

		fundDistribution = nextFundDistribution;
		fundMinSize = nextFundMinSize;

		emit ActivateFund(msg.sender, fundDistribution, fundMinSize);
	}

	// ---------------------------------------------------------------------------------------

	function declareProfit(address from, uint256 value) public _verifyMover {
		if (value == 0) revert NoChange();

		uint256 balanceCommunity = balanceOf(address(funds));

		uint256 distBalance = (totalSupply() * fundDistribution) / 1_000_000;
		uint256 missingMinBalance = balanceCommunity < fundMinSize ? fundMinSize - balanceCommunity : 0;
		uint256 missingDistBalance = balanceCommunity < distBalance ? distBalance - balanceCommunity : 0;
		uint256 maxDistribution = Math.max(missingMinBalance, missingDistBalance);

		if (maxDistribution > 0) {
			_transfer(from, address(funds), maxDistribution);
			funds.declareDeposit(from, maxDistribution);
		}

		if (value - maxDistribution > 0) {
			_transfer(from, address(savings), value - maxDistribution);
			savings.declareDeposit(from, maxDistribution);
		}

		totalProfit += value;
		emit DeclareProfit(from, value, totalProfit);
	}

	function declareLoss(address to, uint256 value) public _verifyMinter {
		_mint(to, value);
		totalLoss += value;
		emit DeclareLoss(to, value, totalLoss);
	}
}
