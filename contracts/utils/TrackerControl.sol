// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';

import './interfaces/ITrackerControl.sol';

contract TrackerControl is ITrackerControl {
	using Math for uint256;

	uint8 private constant TIME_RESOLUTION_BITS = 20;

	uint32 public CAN_ACTIVATE_QUORUM; // @dev: quorum in PPM, for canActivate
	uint256 public CAN_ACTIVATE_DELAY; // @dev: min duration to canActivate

	IERC20 public immutable coin;
	string public name;

	// ---------------------------------------------------------------------------------------
	// Total values

	uint256 public totalBalance;
	uint256 public totalTracksAtAnchor;
	uint256 public totalTracksAnchorTime;

	// ---------------------------------------------------------------------------------------
	// Mapping Tracker

	mapping(address holder => uint256 value) public trackerBalance;
	mapping(address holder => uint64 time) public trackerAnchor;
	mapping(address holder => address delegatee) public trackerDelegate;

	// ---------------------------------------------------------------------------------------
	// Events

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Delegate(address indexed from, address indexed to, uint256 value);
	event Reduced(address indexed from, uint256 value);

	// ---------------------------------------------------------------------------------------
	// Verify Coin

	modifier _verifyOnlyCoin() {
		verifyOnlyCoin(msg.sender);
		_;
	}

	function checkOnlyCoin(address account) public view returns (bool) {
		if (account != address(coin)) return false;
		return true;
	}

	function verifyOnlyCoin(address account) public view {
		if (checkOnlyCoin(account) == false) revert NotCoin(account);
	}

	// ---------------------------------------------------------------------------------------
	// init, set values

	constructor(IERC20 _coin, string memory _name, uint32 _quorum, uint8 _days) {
		coin = _coin;
		name = _name;
		CAN_ACTIVATE_QUORUM = _quorum; // PPM
		CAN_ACTIVATE_DELAY = (uint256(_days) * 1 days) << TIME_RESOLUTION_BITS;
	}

	// ---------------------------------------------------------------------------------------
	// Anchor Time and Tracks

	function _anchorTime() internal view returns (uint64) {
		return uint64(block.timestamp << TIME_RESOLUTION_BITS);
	}

	function totalTracks() public view returns (uint256) {
		return totalTracksAtAnchor + totalBalance * (_anchorTime() - totalTracksAnchorTime);
	}

	function tracksOf(address holder) public view returns (uint256) {
		return trackerBalance[holder] * (_anchorTime() - trackerAnchor[holder]);
	}

	// ---------------------------------------------------------------------------------------
	// Core Functions

	function delegateInfo(address holder) public view returns (address, uint256) {
		address delegatee = trackerDelegate[holder];
		return (delegatee, trackerBalance[delegatee]);
	}

	function _update(address from, address to, uint256 value) public virtual _verifyOnlyCoin {
		(address delegatedFrom, uint256 delegatedFromBalance) = delegateInfo(from);
		(address delegatedTo, uint256 delegatedToBalance) = delegateInfo(to);
		if (delegatedFrom != address(0) || delegatedTo != address(0)) {
			_updateDelegated(delegatedFrom, delegatedFromBalance, delegatedTo, delegatedToBalance, value);
		}
	}

	function _updateDelegated(
		address delegatedFrom,
		uint256 delegatedFromBalance,
		address delegatedTo,
		uint256 delegatedToBalance,
		uint256 value
	) internal {
		uint256 _totalTracks = totalTracks();

		if (delegatedFrom == address(0) && delegatedTo != address(0)) {
			// Overflow check required: The rest of the code assumes that totalSupply never overflows
			totalBalance += value;
		} else if (delegatedFrom != address(0)) {
			// @dev: decrease tracker balance from sender
			if (delegatedFromBalance < value) {
				revert InsufficientBalance(delegatedFrom, delegatedFromBalance, value);
			}
			unchecked {
				// Overflow not possible: value <= delegatedFromBalance <= totalBalance.
				trackerBalance[delegatedFrom] = delegatedFromBalance - value;
			}
		}

		if (delegatedTo == address(0) && delegatedFrom != address(0)) {
			// @dev: remove burned delegated tracks
			_adjustTotalTracks(delegatedFrom, value, _totalTracks, 0); // no rounding error adjustment for address(0)
			// Overflow not possible: value <= totalBalance or value <= delegatedFromBalance.
			totalBalance -= value;
		} else if (delegatedTo != address(0)) {
			// @dev: adjust anchor with tracked tracks divided equially to the new balance
			_adjustRecipientTracks(delegatedFrom, delegatedTo, value, _totalTracks, delegatedToBalance + value);
			unchecked {
				// @dev: decrease tracker balance from sender
				// Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
				trackerBalance[delegatedTo] = delegatedToBalance + value;
			}
		}

		emit Transfer(delegatedFrom, delegatedTo, value);
	}

	function _adjustRecipientTracks(
		address from,
		address to,
		uint256 value,
		uint256 _totalTracks,
		uint256 newBalance
	) internal {
		uint256 tracked = tracksOf(to);
		trackerAnchor[to] = uint64(_anchorTime() - tracked / newBalance);
		_adjustTotalTracks(from, value, _totalTracks, tracked % newBalance);
	}

	function _adjustTotalTracks(address from, uint256 value, uint256 _totalTracks, uint256 roundingLoss) internal {
		uint64 time = _anchorTime();
		uint256 lostTracks = from == address(0) ? 0 : (time - trackerAnchor[from]) * value;
		totalTracksAtAnchor = uint192(_totalTracks - lostTracks - roundingLoss);
		totalTracksAnchorTime = time;
	}

	// ---------------------------------------------------------------------------------------
	// Holding Guard

	function holdingDuration(address holder) public view returns (uint256) {
		return (_anchorTime() - trackerAnchor[holder]) >> TIME_RESOLUTION_BITS;
	}

	function checkHoldingDuration(address holder) public view returns (bool) {
		return _anchorTime() - trackerAnchor[holder] >= CAN_ACTIVATE_DELAY;
	}

	function verifyHoldingDuration(address holder) public view {
		if (checkHoldingDuration(holder) == false) {
			revert NotPassedDuration(holder, holdingDuration(holder), CAN_ACTIVATE_DELAY);
		}
	}

	// ---------------------------------------------------------------------------------------
	// Quorum Guard

	function quorum(address holder) public view returns (uint256) {
		return (tracksOf(holder) * 1_000_000) / totalTracks();
	}

	function checkQuorum(address holder) public view returns (bool) {
		return (tracksOf(holder) * 1_000_000) > totalTracks() * CAN_ACTIVATE_QUORUM;
	}

	function verifyQuorum(address holder) public view {
		if (checkQuorum(holder) == false) {
			revert NotPassedQuorum(holder, quorum(holder), CAN_ACTIVATE_QUORUM);
		}
	}

	// ---------------------------------------------------------------------------------------
	// CanActivate Guard

	function checkCanActivate(address holder) public view returns (bool) {
		return checkHoldingDuration(holder) && checkQuorum(holder);
	}

	function verifyCanActivate(address holder) public view {
		verifyHoldingDuration(holder);
		verifyQuorum(holder);
	}

	// ---------------------------------------------------------------------------------------

	function delegate(address to) public {
		_delegateTo(msg.sender, to);
	}

	function _delegateTo(address holder, address to) internal {
		address before = trackerDelegate[holder];
		if (before == to) revert NoChange();

		trackerDelegate[holder] = to;
		uint256 coinBalance = coin.balanceOf(holder);
		if (coinBalance == 0) return;

		if (before == address(0)) {
			// mint full coin balance
			_updateDelegated(address(0), 0, holder, 0, coinBalance);
		} else if (to == address(0)) {
			// burn full coin balance
			_updateDelegated(before, trackerBalance[before], address(0), 0, coinBalance);
		} else {
			// transfer full coin balance
			_updateDelegated(before, trackerBalance[before], to, trackerBalance[to], coinBalance);
		}
	}

	// ---------------------------------------------------------------------------------------
	// Risk management for 51% attacks

	function reduceOwnTracks(uint value) public {
		_reduceTracks(msg.sender, value);
	}

	function reduceTargetTracks(address target, uint256 value) public {
		uint256 ownTracks = tracksOf(msg.sender);
		uint256 targetTracks = tracksOf(target);
		value = Math.min(Math.min(ownTracks, targetTracks), value);

		_reduceTracks(msg.sender, value);
		_reduceTracks(target, value);
	}

	function _reduceTracks(address target, uint256 value) internal returns (uint256) {
		if (value == 0) revert NoChange();

		uint256 before = tracksOf(target);
		value = Math.min(before, value);
		trackerAnchor[target] = uint64(_anchorTime() - (before - value) / trackerBalance[target]);

		uint256 reduced = before - tracksOf(target);
		emit Reduced(target, reduced);

		return reduced;
	}
}
