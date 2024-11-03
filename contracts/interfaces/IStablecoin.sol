// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../Governance.sol';
import '../Savings.sol';

interface IStablecoin is IERC20 {
	function votes() external view returns (Governance);

	function savings() external view returns (Savings);

	function totalProfit() external view returns (uint256);

	function totalLoss() external view returns (uint256);

	function fundDistribution() external view returns (uint256);

	function fundMinSize() external view returns (uint256);

	function nextFundDistribution() external view returns (uint256);

	function nextFundMinSize() external view returns (uint256);

	function nextFundCanActivate() external view returns (uint256);

	function proposeFundDistribution(uint256 distribution, uint256 size, address[] calldata helpers) external;

	function activateFundDistribution() external;

	function declareProfit(address from, uint256 value) external;

	function declareLoss(address to, uint256 value) external;

	function mint(address account, uint256 value) external;
}
