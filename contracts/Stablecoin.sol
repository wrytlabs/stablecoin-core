// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './Governance.sol';
import './AccessControl.sol';

// import './Savings.sol';

// TODO: ERC20, ERC20Permit, ERC721, ERC...
contract Stablecoin is ERC20, AccessControl {
	using SafeERC20 for ERC20;

	Governance public immutable gov;

	// Savings public immutable savings;

	// ---------------------------------------------------------------------------------------
	constructor() ERC20('Stablecoin', 'STBL') {
		gov = new Governance(this);
		// savings = new Savings(this);
	}

	// ---------------------------------------------------------------------------------------
	// ERC20 Transfer modification
	function _update(address from, address to, uint256 value) internal virtual override {
		// update balance via super
		super._update(from, to, value);

		// update voting power
		gov._update(from, to, value);

		// update interest claim
		// savings._update(from, to, value);
	}

	// ---------------------------------------------------------------------------------------

	// ---------------------------------------------------------------------------------------
	function claimProfit(address from, uint256 value) public verifyMover {
		// make claim
	}

	function mintLoss(address to, uint256 value) public verifyMinter {
		// mint loss
	}
}
