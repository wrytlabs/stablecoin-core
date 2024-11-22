// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/ITrackerControl.sol';

contract TrackerControl is ITrackerControl {
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

	// ---------------------------------------------------------------------------------------
	// Verify Coin

	modifier _verifyOnlyCoin() {
		if (checkOnlyCoin(msg.sender) == false) revert NotCoin();
		_;
	}

	function checkOnlyCoin(address toCheck) public view returns (bool) {
		if (toCheck != address(coin)) return false;
		return true;
	}

	function verifyOnlyCoin(address toCheck) public view _verifyOnlyCoin {}

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
			revert NotPassedDuration(CAN_ACTIVATE_DELAY - holdingDuration(holder));
		}
	}

	// ---------------------------------------------------------------------------------------
	// Quorum Guard

	function quorum(address holder) public view returns (uint256) {
		// ralative ratio scaled to 18 decimals
		return (1 ether * tracksOf(holder)) / totalTracks();
	}

	function checkQuorum(address holder) public view returns (bool) {
		return (tracksOf(holder) * 1_000_000) > totalTracks() * CAN_ACTIVATE_QUORUM;
	}

	function verifyQuorum(address holder) public view {
		if (checkQuorum(holder) == false) revert NotQualified();
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

	// "To respectfully reduce the impact of others, first ensure that you tread lightly yourself."

	// Ensure that you can reduce others' tracks by respectfully reducing your own as well.
	// This mechanism potentially gives full control over the system to whoever has 51% of the votes.

	// function reduceTracks(address[] calldata targets, uint256 tracksToDestroy) external {
	// 	uint256 budget = _reduceTracks(msg.sender, tracksToDestroy);
	// 	uint256 destroyedTracks = 0;
	// 	for (uint256 i = 0; i < targets.length && destroyedTracks < budget; i++) {
	// 		destroyedTracks += _reduceTracks(targets[i], budget - destroyedTracks);
	// 	}
	// 	if (destroyedTracks == 0) revert NotAvailable();
	// 	totalTracksAtAnchor = uint192(totalTracks() - destroyedTracks - budget);
	// 	totalTracksAnchorTime = _anchorTime();
	// }

	// function _reduceTracks(address target, uint256 value) internal returns (uint256) {
	// 	uint256 votesBefore = tracks(target);
	// 	if (value >= votesBefore) {
	// 		value = votesBefore;
	// 		trackerAnchor[target] = _anchorTime();
	// 		return votesBefore;
	// 	} else {
	// 		trackerAnchor[target] = uint64(_anchorTime() - (votesBefore - value) / coin.balanceOf(target));
	// 		return votesBefore - tracks(target);
	// 	}
	// }
}
