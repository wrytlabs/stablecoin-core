// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../Stablecoin.sol';

contract Governance {
	uint32 private constant QUORUM = 2000; // 20 %
	uint8 private constant TIME_RESOLUTION_BITS = 20;
	uint256 public constant MIN_HOLDING_DURATION = 90 days << TIME_RESOLUTION_BITS; // @dev: min holding duration to propose

	Stablecoin public immutable coin;

	uint256 public totalVotesAtAnchor;
	uint256 public totalVotesAnchorTime;

	// ---------------------------------------------------------------------------------------

	error NotStableCoin();
	error MinHoldingDuration();
	error NotQualified();

	// ---------------------------------------------------------------------------------------

	mapping(address owner => address delegate) public delegates;
	mapping(address holder => uint64 timestamp) private voteAnchor;

	// ---------------------------------------------------------------------------------------

	constructor(Stablecoin _coin) {
		coin = _coin;
	}

	// ---------------------------------------------------------------------------------------

	function totalVotes() public view returns (uint256) {
		return totalVotesAtAnchor + coin.totalSupply() * (_anchorTime() - totalVotesAnchorTime);
	}

	function votes(address holder) public view returns (uint256) {
		if (_anchorTime() - voteAnchor[holder] < MIN_HOLDING_DURATION) return 0;
		return coin.balanceOf(holder) * (_anchorTime() - voteAnchor[holder]);
	}

	function relativeVotes(address holder) public view returns (uint256) {
		return (1 ether * votes(holder)) / totalVotes();
	}

	function _update(address from, address to, uint256 value) public {
		if (msg.sender != address(coin)) revert NotStableCoin();
		uint256 roundingLoss = _adjustRecipientVoteAnchor(to, value);
		_adjustTotalVotes(from, value, roundingLoss);
	}

	function _anchorTime() internal view returns (uint64) {
		return uint64(block.timestamp << TIME_RESOLUTION_BITS);
	}

	function _adjustRecipientVoteAnchor(address to, uint256 amount) internal returns (uint256) {
		if (to != address(0x0)) {
			uint256 recipientVotes = votes(to); // for example 21 if 7 shares were held for 3 seconds
			uint256 newbalance = coin.balanceOf(to) + amount; // for example 11 if 4 shares are added
			// new example anchor is only 21 / 11 = 1 second in the past
			voteAnchor[to] = uint64(_anchorTime() - recipientVotes / newbalance);
			return recipientVotes % newbalance; // we have lost 21 % 11 = 10 votes
		} else {
			return 0; // vote anchor of null address does not matter
		}
	}

	function _adjustTotalVotes(address from, uint256 amount, uint256 roundingLoss) internal {
		uint64 time = _anchorTime();
		uint256 lostVotes = from == address(0x0) ? 0 : (time - voteAnchor[from]) * amount;
		totalVotesAtAnchor = uint192(totalVotes() - roundingLoss - lostVotes);
		totalVotesAnchorTime = time;
	}

	// ---------------------------------------------------------------------------------------

	function holdingDuration(address holder) public view returns (uint256) {
		return (_anchorTime() - voteAnchor[holder]) >> TIME_RESOLUTION_BITS;
	}

	function checkHoldingDuration(address holder) public view {
		if (_anchorTime() - voteAnchor[holder] < MIN_HOLDING_DURATION) revert MinHoldingDuration();
	}

	function checkCanPropose(address sender, address[] calldata helpers) public view {
		uint256 _votes = votesDelegated(sender, helpers);
		if (_votes * 10000 < QUORUM * totalVotes()) revert NotQualified();
	}

	function votesDelegated(address sender, address[] calldata helpers) public view returns (uint256) {
		require(_checkDuplicatesAndSorted(helpers));
		uint256 _votes = votes(sender);
		for (uint i = 0; i < helpers.length; i++) {
			address current = helpers[i];
			require(current != sender);
			require(_canVoteFor(sender, current));
			_votes += votes(current);
		}
		return _votes;
	}

	function _canVoteFor(address delegate, address owner) internal view returns (bool) {
		if (owner == delegate) {
			return true;
		} else if (owner == address(0x0)) {
			return false;
		} else {
			return _canVoteFor(delegate, delegates[owner]);
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

	/**
	 * @notice Since quorum is rather low, it is important to have a way to prevent malicious minority holders
	 * from blocking the whole system. This method provides a way for the good guys to team up and destroy
	 * the bad guy's votes (at the cost of also reducing their own votes). This mechanism potentially
	 * gives full control over the system to whoever has 51% of the votes.
	 *
	 * Since this is a rather aggressive measure, delegation is not supported. Every holder must call this
	 * method on their own.
	 * @param targets   The target addresses to remove votes from
	 * @param votesToDestroy    The maximum number of votes the caller is willing to sacrifice
	 */
	function kamikaze(address[] calldata targets, uint256 votesToDestroy) external {
		uint256 budget = _reduceVotes(msg.sender, votesToDestroy);
		uint256 destroyedVotes = 0;
		for (uint256 i = 0; i < targets.length && destroyedVotes < budget; i++) {
			destroyedVotes += _reduceVotes(targets[i], budget - destroyedVotes);
		}
		require(destroyedVotes > 0); // sanity check
		totalVotesAtAnchor = uint192(totalVotes() - destroyedVotes - budget);
		totalVotesAnchorTime = _anchorTime();
	}

	function _reduceVotes(address target, uint256 amount) internal returns (uint256) {
		uint256 votesBefore = votes(target);
		if (amount >= votesBefore) {
			amount = votesBefore;
			voteAnchor[target] = _anchorTime();
			return votesBefore;
		} else {
			voteAnchor[target] = uint64(_anchorTime() - (votesBefore - amount) / coin.balanceOf(target));
			return votesBefore - votes(target);
		}
	}
}
