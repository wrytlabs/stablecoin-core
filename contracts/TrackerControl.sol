// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './Stablecoin.sol';

contract TrackerControl {
	uint8 private constant TIME_RESOLUTION_BITS = 20;

	uint32 public QUORUM; // @dev: quorum in PPM, for canActivate
	uint256 public MIN_HOLDING_DURATION; // @dev: min duration to canActivate

	Stablecoin public immutable coin;
	string public name;

	uint256 public totalTracksAtAnchor;
	uint256 public totalTracksAnchorTime;

	// ---------------------------------------------------------------------------------------

	error NotStableCoin();
	error MinHoldingDuration();
	error NotQualified();

	// ---------------------------------------------------------------------------------------

	mapping(address owner => address delegate) public delegates;
	mapping(address holder => uint64 timestamp) private trackerAnchor;

	// ---------------------------------------------------------------------------------------

	constructor(Stablecoin _coin, string memory _name, uint32 _quorum, uint8 _days) {
		coin = _coin;
		name = _name;
		QUORUM = _quorum; // PPM
		MIN_HOLDING_DURATION = (uint256(_days) * 1 days) << TIME_RESOLUTION_BITS;
	}

	// ---------------------------------------------------------------------------------------

	function totalTracks() public view returns (uint256) {
		return totalTracksAtAnchor + coin.totalSupply() * (_anchorTime() - totalTracksAnchorTime);
	}

	function tracks(address holder) public view returns (uint256) {
		if (_anchorTime() - trackerAnchor[holder] < MIN_HOLDING_DURATION) return 0;
		return coin.balanceOf(holder) * (_anchorTime() - trackerAnchor[holder]);
	}

	function relativeTracks(address holder) public view returns (uint256) {
		return (1 ether * tracks(holder)) / totalTracks();
	}

	function _update(address from, address to, uint256 amount) public {
		if (msg.sender != address(coin)) revert NotStableCoin();
		uint256 roundingLoss = _adjustRecipientTracksAnchor(to, amount);
		_adjustTotalTracks(from, amount, roundingLoss);
	}

	function _anchorTime() internal view returns (uint64) {
		return uint64(block.timestamp << TIME_RESOLUTION_BITS);
	}

	function _adjustRecipientTracksAnchor(address to, uint256 amount) internal returns (uint256) {
		if (to != address(0x0)) {
			uint256 recipient = tracks(to); // for example 21 if 7 shares were held for 3 seconds
			uint256 newbalance = coin.balanceOf(to) + amount; // for example 11 if 4 shares are added
			// new example anchor is only 21 / 11 = 1 second in the past
			trackerAnchor[to] = uint64(_anchorTime() - recipient / newbalance);
			return recipient % newbalance; // we have lost 21 % 11 = 10 tracks
		} else {
			return 0; // vote anchor of null address does not matter
		}
	}

	function _adjustTotalTracks(address from, uint256 amount, uint256 roundingLoss) internal {
		uint64 time = _anchorTime();
		uint256 lostVotes = from == address(0x0) ? 0 : (time - trackerAnchor[from]) * amount;
		totalTracksAtAnchor = uint192(totalTracks() - roundingLoss - lostVotes);
		totalTracksAnchorTime = time;
	}

	// ---------------------------------------------------------------------------------------

	function holdingDuration(address holder) public view returns (uint256) {
		return (_anchorTime() - trackerAnchor[holder]) >> TIME_RESOLUTION_BITS;
	}

	function verifyHoldingDuration(address holder) public view returns (bool) {
		return _anchorTime() - trackerAnchor[holder] >= MIN_HOLDING_DURATION;
	}

	function checkHoldingDuration(address holder) public view {
		if (verifyHoldingDuration(holder) == false) revert MinHoldingDuration();
	}

	// ---------------------------------------------------------------------------------------

	function verifyCanActivate(address holder, address[] calldata helpers) public view returns (bool) {
		uint256 _tracks = tracksDelegated(holder, helpers);
		return (_tracks * 1_000_000 > QUORUM * totalTracks());
	}

	function checkCanActivate(address holder, address[] calldata helpers) public view {
		if (verifyCanActivate(holder, helpers) == false) revert NotQualified();
	}

	function tracksDelegated(address sender, address[] calldata helpers) public view returns (uint256) {
		require(_checkDuplicatesAndSorted(helpers));
		uint256 _tracks = tracks(sender);
		for (uint i = 0; i < helpers.length; i++) {
			address current = helpers[i];
			require(current != sender);
			require(_canActivateFor(sender, current));
			_tracks += tracks(current);
		}
		return _tracks;
	}

	function _canActivateFor(address delegate, address owner) internal view returns (bool) {
		if (owner == delegate) {
			return true;
		} else if (owner == address(0x0)) {
			return false;
		} else {
			return _canActivateFor(delegate, delegates[owner]);
		}
	}

	function _checkDuplicatesAndSorted(address[] calldata helpers) internal pure returns (bool ok) {
		if (helpers.length <= 1) {
			return true;
		} else {
			address prevAddress = helpers[0];
			for (uint i = 1; i < helpers.length; i++) {
				if (helpers[i] <= prevAddress) {
					return false;
				}
				prevAddress = helpers[i];
			}
			return true;
		}
	}
}
