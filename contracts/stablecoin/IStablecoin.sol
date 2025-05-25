// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IStablecoin is IERC20 {
	// Core Accounting
	function totalInflow() external view returns (uint256);

	function totalDebtMinted() external view returns (uint256);

	function totalDebtCovered() external view returns (uint256);

	// Modules functions
	function configModule(address module, bool activate, string calldata message) external;

	// Core functions
	function mint(address account, uint256 value) external;

	function inflow(address from, uint256 value) external;

	function outflow(address to, uint256 value) external;
}
