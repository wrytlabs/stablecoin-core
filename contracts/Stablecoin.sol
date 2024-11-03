// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './AccessControl.sol';
import './Governance.sol';
import './Savings.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is ERC20, AccessControl {
	using SafeERC20 for ERC20;

	Governance public immutable votes;
	Savings public immutable savings;

	// ---------------------------------------------------------------------------------------

	constructor() ERC20('Stablecoin', 'STBL') {
		votes = new Governance(this, 'Votes', 20_000, 90);
		savings = new Savings(this, 'Savings', 0, 3);
	}

	// ---------------------------------------------------------------------------------------
	// ERC20 modifications
	function _update(address from, address to, uint256 value) internal virtual override {
		// update balance via super
		super._update(from, to, value);

		// update voting power
		votes._update(from, to, value);

		// update interest claim
		savings._update(from, to, value);
	}

	function allowance(address owner, address spender) public view virtual override returns (uint256) {
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

	function claimProfit(address from, uint256 value) public _verifyMover {
		// make claim
	}

	function mintLoss(address to, uint256 value) public _verifyMinter {
		// mint loss
	}
}
