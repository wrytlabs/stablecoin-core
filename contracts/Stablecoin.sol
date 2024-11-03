// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './interfaces/IStablecoin.sol';
import './AccessControl.sol';
import './Governance.sol';
import './Savings.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is ERC20, AccessControl {
	using SafeERC20 for ERC20;

	uint256 public constant CAN_ACTIVATE_DELAY = 30 days;

	Governance public immutable votes;
	Savings public immutable savings;

	uint256 public totalProfit;
	uint256 public totalLoss;

	uint256 public fundDistribution = 5_000; // 5% in PPM
	uint256 public fundMinSize = 10_000 ether;
	uint256 public nextFundDistribution;
	uint256 public nextFundMinSize;
	uint256 public nextFundCanActivate;

	// ---------------------------------------------------------------------------------------

	event ProposeFund(address indexed proposer, uint256 distribution, uint256 minSize, uint256 canActivate);
	event ActivatedFund(address indexed sender, uint256 distribution, uint256 minSize);
	event DeclareProfit(address indexed sender, uint256 value, uint256 total);
	event DeclareLoss(address indexed sender, uint256 value, uint256 total);

	// ---------------------------------------------------------------------------------------

	error NoChange();
	error NotActive();

	// ---------------------------------------------------------------------------------------

	constructor() ERC20('Stablecoin', 'STBL') {
		votes = new Governance(this, 'Votes', 20_000, 90);
		savings = new Savings(this, 'Savings', 0, 3);
	}

	// ---------------------------------------------------------------------------------------
	// ERC20 modifications
	function _update(address from, address to, uint256 value) internal virtual override {
		// openzeppelin: use "value"
		// update voting power
		votes._update(from, to, value);

		// update interest claim
		savings._update(from, to, value);

		// update balance via super
		super._update(from, to, value);
	}

	function allowance(address owner, address spender) public view virtual override(ERC20, IERC20) returns (uint256) {
		if (isMover[spender] == true) return type(uint256).max;
		return super.allowance(owner, spender);
	}

	// ---------------------------------------------------------------------------------------

	// function proposeMinter(address minter, ) public {
	// 	address[] memory emptyArray;
	// 	votes.checkCanActivate(msg.sender, emptyArray);
	// }

	function mint(address account, uint256 value) public _verifyMinter {
		_mint(account, value);
	}

	// ---------------------------------------------------------------------------------------

	function proposeFundDistribution(uint256 distribution, uint256 size, address[] calldata helpers) public {
		votes.verifyCanActivate(msg.sender, helpers);

		if (fundDistribution == distribution && fundMinSize == size) revert NoChange();

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

		emit ActivatedFund(msg.sender, fundDistribution, fundMinSize);
	}

	// ---------------------------------------------------------------------------------------

	function declareProfit(address from, uint256 value) public _verifyMover {
		uint256 balanceGovernance = balanceOf(address(votes));

		if (balanceGovernance * 1_000_000 < totalSupply() * fundDistribution) {
			// claim for community fund
			_transfer(from, address(votes), value);
		} else {
			// claim for savings (stablecoin holders)
			_transfer(from, address(savings), value);
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
