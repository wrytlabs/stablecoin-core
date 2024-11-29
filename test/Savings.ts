import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Savings, Stablecoin } from '../typechain';

describe('Savings - Smart Contract', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let bob: HardhatEthersSigner;

	let stablecoin: Stablecoin;
	let savings: Savings;

	before('Should deploy Stablecoin with correct parameters', async () => {
		[owner, alice, bob] = await ethers.getSigners();

		const Stablecoin = await ethers.getContractFactory('Stablecoin');
		stablecoin = await Stablecoin.deploy(
			'Wryt USD', // name
			'wyUSD', // symbol
			20_000, // 20% votesQuorumPPM
			90, // 90 votesActivateDays
			0, // 0% savingsQuorumPPM
			3 // 3 savingsActivateDays
		);

		// Get Savings contract instance
		const savingsAddress = await stablecoin.savings();
		savings = await ethers.getContractAt('Savings', savingsAddress);
	});

	// describe('Basic Savings Tests', () => {
	// 	it('should have correct constructor values', async () => {
	// 		expect(await savings.name()).to.equal('Savings');
	// 		expect(await savings.CAN_ACTIVATE_QUORUM()).to.equal(0);
	// 		// expect(await savings.CAN_ACTIVATE_DELAY()).to.equal((3 * 60 * 60 * 24) << 20);
	// 	});
	// });
});
