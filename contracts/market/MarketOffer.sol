// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

struct Offer {
	address maker;
	address tokenIn;
	address tokenOut;
	uint256 price;
	uint256 amount;
	uint256 minAmount;
}

contract MarketOffer is ERC721 {
	using Math for uint256;
	using SafeERC20 for IERC20;

	uint256 public tokenCnt;
	mapping(uint256 id => Offer) public offers;

	// ---------------------------------------------------------------------------------------

	event Created(uint256 id, address tokenIn, address tokenOut, uint256 price, uint256 amount, uint256 minAmount);
	event Cancelled(uint256 id);
	event Filled(uint256 id, uint256 take, uint256 left);

	error InvalidOffer(uint256 amount, uint256 minAmount);
	error InvalidInput(uint256 take, uint256 give);
	error InvalidAmount(uint256 available, uint256 wanted);
	error InvalidDust(uint256 dustAmount, uint256 minAmount);

	// ---------------------------------------------------------------------------------------

	constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

	// ---------------------------------------------------------------------------------------

	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	// ---------------------------------------------------------------------------------------

	function create(address tokenIn, address tokenOut, uint256 price, uint256 amount, uint256 minAmount) external {
		_createFrom(msg.sender, msg.sender, tokenIn, tokenOut, price, amount, minAmount);
	}

	function createFrom(
		address from,
		address onBehalf,
		address tokenIn,
		address tokenOut,
		uint256 price,
		uint256 amount,
		uint256 minAmount
	) external {
		_createFrom(from, onBehalf, tokenIn, tokenOut, price, amount, minAmount);
	}

	function _createFrom(
		address from,
		address onBehalf,
		address tokenIn,
		address tokenOut,
		uint256 price,
		uint256 amount,
		uint256 minAmount
	) internal {
		if (minAmount > amount) revert InvalidOffer(amount, minAmount);

		// deposit initial funds
		IERC20(tokenIn).safeTransferFrom(from, address(this), amount);

		// create offer
		tokenCnt += 1;
		offers[tokenCnt] = Offer(onBehalf, tokenIn, tokenOut, price, amount, minAmount);

		// mint ownership token
		_safeMint(onBehalf, tokenCnt);
		emit Created(tokenCnt, tokenIn, tokenOut, price, amount, minAmount);
	}

	// ---------------------------------------------------------------------------------------

	function cancel(uint256 id, address target) external {
		Offer memory offer = offers[id];

		// check
		if (offer.maker == address(0)) {
			revert ERC721NonexistentToken(id);
		} else if (offer.maker != msg.sender) {
			revert ERC721IncorrectOwner(msg.sender, id, offer.maker);
		}

		// remove entries
		delete offers[id];
		_burn(id);

		// return funds
		IERC20(offer.tokenIn).safeTransfer(target, offer.amount);

		// event
		emit Cancelled(id);
	}

	// ---------------------------------------------------------------------------------------

	function fill(uint256 id, address from, address target, uint256 take, uint256 give) external {
		Offer memory offer = offers[id];

		// check existance
		if (offer.maker == address(0)) {
			revert ERC721NonexistentToken(id);
		}

		// make params available
		if (give > 0) {
			take = (give * 1 ether) / offer.price;
		} else {
			give = (take * offer.price) / 1 ether;
		}

		// inputs validation
		if (take == 0 || give == 0) revert InvalidInput(take, give);
		if (take > offer.amount) revert InvalidAmount(offer.amount, take);

		uint256 dust = offer.amount - take;
		if (dust > 0 && dust < offer.minAmount) revert InvalidDust(dust, offer.minAmount);

		// partial or full fill
		if (take < offer.amount) {
			offers[id].amount -= take;
		} else {
			delete offers[id];
			_burn(id);
		}

		// transfers of funds
		IERC20(offer.tokenOut).safeTransferFrom(from, offer.maker, give); // from -> maker
		IERC20(offer.tokenIn).safeTransfer(target, take); // this -> target address

		// event
		emit Filled(id, take, dust);
	}
}
