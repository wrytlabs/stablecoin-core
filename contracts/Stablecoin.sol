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
	uint256 public totalOutflowMinted;
	uint256 public totalOutflowCovered;

	// ---------------------------------------------------------------------------------------

	event DeclareInflow(address indexed sender, uint256 value, uint256 covered, uint256 totalInflow);
	event DeclareOutflow(
		address indexed sender,
		uint256 value,
		uint256 covered,
		uint256 totalOutflowCovered,
		uint256 totalOutflowMinted
	);

	// ---------------------------------------------------------------------------------------

	constructor(
		string memory name_,
		string memory symbol_,
		uint32 votesQuorumPPM_,
		uint8 votesActivateDays_,
		uint32 savingsQuorumPPM_,
		uint8 savingsActivateDays_
	) ERC20(name_, symbol_) {
		votes = new Governance(this, 'Votes', votesQuorumPPM_, votesActivateDays_);
		savings = new Savings(this, 'Savings', savingsQuorumPPM_, savingsActivateDays_);
	}

	function setModule(address module, string calldata message) public {
		if (totalSupply() > 0) revert NotAvailable();
		isModule[module] = true;
		moduleActivation[module] = block.timestamp;
		moduleExpiration[module] = type(uint256).max;
		emit ModuleUpdated(msg.sender, module, message, true, block.timestamp, type(uint256).max);
	}

	function configModule(address module, bool activate, string calldata message) public {
		votes.verifyCanActivate(msg.sender);
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
		if (checkModule(msg.sender) == true) return type(uint256).max;
		return super.allowance(owner, spender);
	}

	// ---------------------------------------------------------------------------------------

	function mint(address to, uint256 value) public _verifyModule {
		if (to == address(0) || value == 0) revert NoChange(); // @dev: might change to pass without reverting
		_mint(to, value); // emits ERC20 Transfer
	}

	function declareInflow(address from, uint256 value) public _verifyModule {
		if (from == address(0) || value == 0) revert NoChange(); // @dev: might change to pass without reverting

		// totalOutflowMinted
		uint256 cover = totalOutflowMinted >= value ? value : totalOutflowMinted;

		if (cover > 0) {
			_burn(from, cover);
			totalOutflowMinted -= cover;
		}

		if (value > cover) {
			uint256 missing = value - cover;
			_transfer(from, address(savings), missing);
			savings.declareDeposit(from, missing);
		}

		totalInflow += value;
		emit DeclareInflow(from, value, totalInflow, cover);
	}

	function declareOutflow(address to, uint256 value) public _verifyModule {
		if (to == address(0) || value == 0) revert NoChange(); // @dev: might change to pass without reverting

		uint256 saved = balanceOf(address(savings));
		uint256 refund = saved >= value ? value : saved;

		// @dev: refund from savings
		if (refund > 0) {
			_transfer(address(savings), to, refund);
			totalOutflowCovered += refund;
		}

		// @dev: mint to cover missing outflow
		if (value > refund) {
			uint256 missing = value - refund; // Overflow not possible
			_mint(to, missing); // mint missing
			totalOutflowMinted += missing; //  we know fits into an uint256
		}

		emit DeclareOutflow(to, value, refund, totalOutflowCovered, totalOutflowMinted);
	}
}
