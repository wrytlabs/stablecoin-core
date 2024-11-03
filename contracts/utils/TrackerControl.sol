// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/ITrackerControl.sol';
import '../interfaces/IStablecoin.sol';

contract TrackerControl is ITrackerControl {
	using SafeERC20 for IERC20;

	uint8 private constant TIME_RESOLUTION_BITS = 20;

	uint32 public QUORUM; // @dev: quorum in PPM, for canActivate
	uint256 public MIN_HOLDING_DURATION; // @dev: min duration to canActivate

	IStablecoin public immutable coin;
	string public name;

	uint256 public totalTracksAtAnchor;
	uint256 public totalTracksAnchorTime;

	// ---------------------------------------------------------------------------------------

	mapping(address owner => address delegate) public delegates;
	mapping(address holder => uint64 timestamp) private trackerAnchor;

	// ---------------------------------------------------------------------------------------

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

	constructor(IStablecoin _coin, string memory _name, uint32 _quorum, uint8 _days) {
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

	function _update(address from, address to, uint256 amount) public _verifyOnlyCoin {
		uint256 roundingLoss = _adjustRecipientTracksAnchor(to, amount);
		_adjustTotalTracks(from, amount, roundingLoss);
	}

	function _anchorTime() internal view returns (uint64) {
		return uint64(block.timestamp << TIME_RESOLUTION_BITS);
	}

	function _adjustRecipientTracksAnchor(address to, uint256 amount) internal returns (uint256) {
		if (to == address(0)) {
			return 0; // address zero does not matter
		} else {
			uint256 tracked = tracks(to); // for example 21 if 7 shares were held for 3 seconds
			uint256 newBalance = coin.balanceOf(to) + amount; // for example 11 if 4 shares are added
			trackerAnchor[to] = uint64(_anchorTime() - tracked / newBalance); // anchor is 21 / 11 = 1 second in the past
			return tracked % newBalance; // we have lost 21 % 11 = 10 tracks
		}
	}

	function _adjustTotalTracks(address from, uint256 amount, uint256 roundingLoss) internal {
		uint64 time = _anchorTime();
		uint256 lostTracks = from == address(0) ? 0 : (time - trackerAnchor[from]) * amount;
		totalTracksAtAnchor = uint192(totalTracks() - lostTracks - roundingLoss);
		totalTracksAnchorTime = time;
	}

	// ---------------------------------------------------------------------------------------

	function holdingDuration(address holder) public view returns (uint256) {
		return (_anchorTime() - trackerAnchor[holder]) >> TIME_RESOLUTION_BITS;
	}

	function checkHoldingDuration(address holder) public view returns (bool) {
		return _anchorTime() - trackerAnchor[holder] >= MIN_HOLDING_DURATION;
	}

	function verifyHoldingDuration(address holder) public view {
		if (checkHoldingDuration(holder) == false) revert NotPassedDuration();
	}

	// ---------------------------------------------------------------------------------------

	function checkCanActivate(address holder, address[] calldata helpers) public view returns (bool) {
		uint256 _tracks = tracksDelegated(holder, helpers);
		return (_tracks * 1_000_000 > QUORUM * totalTracks());
	}

	function verifyCanActivate(address holder, address[] calldata helpers) public view {
		if (checkCanActivate(holder, helpers) == false) revert NotQualified();
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

	// ---------------------------------------------------------------------------------------

	// "To respectfully reduce the impact of others, first ensure that you tread lightly yourself."

	// Ensure that you can reduce others' tracks by respectfully reducing your own as well.
	// This mechanism potentially gives full control over the system to whoever has 51% of the votes.

	function reduceTracks(address[] calldata targets, uint256 tracksToDestroy) external {
		uint256 budget = _reduceTracks(msg.sender, tracksToDestroy);
		uint256 destroyedTracks = 0;
		for (uint256 i = 0; i < targets.length && destroyedTracks < budget; i++) {
			destroyedTracks += _reduceTracks(targets[i], budget - destroyedTracks);
		}
		if (destroyedTracks == 0) revert NotAvailable();
		totalTracksAtAnchor = uint192(totalTracks() - destroyedTracks - budget);
		totalTracksAnchorTime = _anchorTime();
	}

	function _reduceTracks(address target, uint256 amount) internal returns (uint256) {
		uint256 votesBefore = tracks(target);
		if (amount >= votesBefore) {
			amount = votesBefore;
			trackerAnchor[target] = _anchorTime();
			return votesBefore;
		} else {
			trackerAnchor[target] = uint64(_anchorTime() - (votesBefore - amount) / coin.balanceOf(target));
			return votesBefore - tracks(target);
		}
	}
}
