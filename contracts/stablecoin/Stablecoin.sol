// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC1363} from '@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IStablecoin, IERC20} from './IStablecoin.sol';
import {ModuleAccess} from '../access/ModuleAccess.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is ERC20, ERC20Permit, ERC1363, Ownable2Step, ModuleAccess, IStablecoin {
	using Math for uint256;
	using SafeERC20 for ERC20;

	uint256 public totalInflow;
	uint256 public totalDebtMinted;
	uint256 public totalDebtCovered;

	// ---------------------------------------------------------------------------------------

	event DeclareInflow(address indexed sender, uint256 value, uint256 covered, uint256 totalInflow);
	event DeclareOutflow(
		address indexed sender,
		uint256 value,
		uint256 covered,
		uint256 totalDebtCovered,
		uint256 totalDebtMinted
	);

	// ---------------------------------------------------------------------------------------

	error InvalidZero();

	// ---------------------------------------------------------------------------------------

	modifier onlyOwnerOrModule() {
		address m = _msgSender();
		if (m != owner()) verifyModule(m);
		_;
	}

	// ---------------------------------------------------------------------------------------

	constructor(
		string memory _name,
		string memory _symbol,
		address _dao
	) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(_dao) {}

	function configModule(address module, bool activate, string calldata message) public onlyOwner {
		_configModule(module, activate, message);
	}

	// ---------------------------------------------------------------------------------------
	// ERC20 modifications
	function _update(address from, address to, uint256 value) internal virtual override {
		super._update(from, to, value);
	}

	function allowance(address owner, address spender) public view virtual override(ERC20, IERC20) returns (uint256) {
		if (checkModule(_msgSender()) == true) return type(uint256).max;
		return super.allowance(owner, spender);
	}

	// ---------------------------------------------------------------------------------------

	function mint(address to, uint256 value) public onlyOwnerOrModule {
		if (value == 0) revert InvalidZero(); // @dev: restrict zero mints
		_mint(to, value); // checks zeroAddress and emits ERC20 Transfer
	}

	function permitAndTransferFrom(
		address owner,
		address to,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external {
		// Approve spender (msg.sender) via permit
		permit(owner, _msgSender(), value, deadline, v, r, s);

		// Transfer tokens from owner to recipient
		transferFrom(owner, to, value);
	}

	// ---------------------------------------------------------------------------------------

	function inflow(address from, uint256 value) public onlyOwnerOrModule {
		if (value == 0) revert InvalidZero();

		// totalDebtMinted
		uint256 cover = totalDebtMinted >= value ? value : totalDebtMinted;

		if (cover > 0) {
			_burn(from, cover);
			totalDebtMinted -= cover;
		}

		if (value > cover) {
			uint256 missing = value - cover;
			_transfer(from, address(owner()), missing);
		}

		totalInflow += value;
		emit DeclareInflow(from, value, totalInflow, cover);
	}

	// ---------------------------------------------------------------------------------------

	function outflow(address to, uint256 value) public onlyOwnerOrModule {
		if (value == 0) revert InvalidZero();

		uint256 saved = balanceOf(address(owner()));
		uint256 refund = saved >= value ? value : saved;

		// @dev: refund from savings
		if (refund > 0) {
			_transfer(address(owner()), to, refund);
			totalDebtCovered += refund;
		}

		// @dev: mint to cover missing outflow
		if (value > refund) {
			uint256 missing = value - refund; // Overflow not possible
			_mint(to, missing); // mint missing
			totalDebtMinted += missing; //  we know fits into an uint256
		}

		emit DeclareOutflow(to, value, refund, totalDebtCovered, totalDebtMinted);
	}
}
