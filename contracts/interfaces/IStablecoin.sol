// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../utils/interfaces/IAccessControl.sol';

import '../Governance.sol';
import '../Savings.sol';

interface IStablecoin is IERC20, IAccessControl {
	// State view functions
	function votes() external view returns (Governance);

	function savings() external view returns (Savings);

	function totalInflow() external view returns (uint256);

	function totalOutflowMinted() external view returns (uint256);

	function totalOutflowCovered() external view returns (uint256);

	// Modules functions
	function setModule(address module, string calldata message) external;

	function configModule(address module, bool activate, string calldata message) external;

	// Core functions
	function mint(address account, uint256 value) external;

	function declareInflow(address from, uint256 value) external;

	function declareOutflow(address to, uint256 value) external;
}
