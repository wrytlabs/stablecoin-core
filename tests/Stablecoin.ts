import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Stablecoin } from '../typechain';

describe('Stablecoin Deployment', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;

	let stablecoin: Stablecoin;

	before('Should deploy Stablecoin with correct parameters', async () => {
		[owner, alice] = await ethers.getSigners();

		const Stablecoin = await ethers.getContractFactory('Stablecoin');
		stablecoin = await Stablecoin.deploy(
			'Wryt USD', // name
			'wyUSD', // symbol
			20_000, // 20% votesQuorumPPM
			90, // 90 votesActivateDays
			0, // 0% savingsQuorumPPM
			3 // 3 savingsActivateDays
		);
	});

	describe('Basic checks for deployment', () => {
		it('should return the correct name and symbol', async () => {
			expect(await stablecoin.name()).to.equal('Wryt USD');
			expect(await stablecoin.symbol()).to.equal('wyUSD');
		});

		it('should return an address for votes and savings', async () => {
			const votes = await stablecoin.votes();
			const savings = await stablecoin.savings();

			expect(votes).to.not.equal(ethers.ZeroAddress);
			expect(savings).to.not.equal(ethers.ZeroAddress);
		});
	});
});
