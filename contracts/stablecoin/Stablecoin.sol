// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IStablecoin, IERC20} from './IStablecoin.sol';
import {ModuleAccess} from '../access/ModuleAccess.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is ERC20, Ownable2Step, ModuleAccess, IStablecoin {
	using Math for uint256;
	using SafeERC20 for ERC20;

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

	error InvalidMint();

	// ---------------------------------------------------------------------------------------

	constructor(string memory _name, string memory _symbol, address _dao) ERC20(_name, _symbol) Ownable(_dao) {}

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

	function mint(address to, uint256 value) public _verifyModule {
		if (value == 0) revert InvalidMint(); // @dev: restrict zero mints
		_mint(to, value); // checks zeroAddress and emits ERC20 Transfer
	}

	// function declareInflow(address from, uint256 value) public _verifyModule {
	// 	if (from == address(0) || value == 0) revert NoChange(); // @dev: might change to pass without reverting

	// 	// totalOutflowMinted
	// 	uint256 cover = totalOutflowMinted >= value ? value : totalOutflowMinted;

	// 	if (cover > 0) {
	// 		_burn(from, cover);
	// 		totalOutflowMinted -= cover;
	// 	}

	// 	if (value > cover) {
	// 		uint256 missing = value - cover;
	// 		_transfer(from, address(savings), missing);
	// 		savings.declareDeposit(from, missing);
	// 	}

	// 	totalInflow += value;
	// 	emit DeclareInflow(from, value, totalInflow, cover);
	// }

	// function declareOutflow(address to, uint256 value) public _verifyModule {
	// 	if (to == address(0) || value == 0) revert NoChange(); // @dev: might change to pass without reverting

	// 	uint256 saved = balanceOf(address(savings));
	// 	uint256 refund = saved >= value ? value : saved;

	// 	// @dev: refund from savings
	// 	if (refund > 0) {
	// 		_transfer(address(savings), to, refund);
	// 		totalOutflowCovered += refund;
	// 	}

	// 	// @dev: mint to cover missing outflow
	// 	if (value > refund) {
	// 		uint256 missing = value - refund; // Overflow not possible
	// 		_mint(to, missing); // mint missing
	// 		totalOutflowMinted += missing; //  we know fits into an uint256
	// 	}

	// 	emit DeclareOutflow(to, value, refund, totalOutflowCovered, totalOutflowMinted);
	// }
}
