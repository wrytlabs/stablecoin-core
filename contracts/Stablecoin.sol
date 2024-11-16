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

	Governance public immutable votes;
	Savings public immutable savings;

	uint256 public totalInflow;
	uint256 public totalOutflow;
	uint256 public totalOutflowCovered;

	// ---------------------------------------------------------------------------------------

	event DeclareInflow(address indexed sender, uint256 value, uint256 total);
	event DeclareOutflow(address indexed sender, uint256 value, uint256 covered, uint256 total);

	// ---------------------------------------------------------------------------------------

	constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
		votes = new Governance(this, 'Votes', 20_000, 90);
		savings = new Savings(this, 'Savings', 0, 3);
	}

	function setModule(address to, string calldata message) public {
		if (totalSupply() > 0) revert NotAvailable();
		isModule[to] = true;
		moduleActivation[to] = block.timestamp;
		moduleExpiration[to] = type(uint256).max;
		emit ModuleUpdated(msg.sender, to, message, true, block.timestamp, type(uint256).max);
	}

	function configModule(address module, bool activate, string calldata message, address[] calldata helpers) public {
		votes.checkCanActivate(msg.sender, helpers);
		_configModule(module, activate, message);
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
		if (checkModule(spender) == true) return type(uint256).max;
		return super.allowance(owner, spender);
	}

	function mint(address account, uint256 value) public _verifyModule {
		_mint(account, value);
	}

	// ---------------------------------------------------------------------------------------

	function declareInflow(address from, uint256 value) public _verifyModule {
		if (value == 0) revert NoChange(); // @dev: might change to pass without reverting

		_transfer(from, address(savings), value);
		savings.declareDeposit(from, value);

		totalInflow += value;
		emit DeclareInflow(from, value, totalInflow);
	}

	function declareOutflow(address to, uint256 value) public _verifyModule {
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
