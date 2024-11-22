import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Stablecoin } from '../typechain';

describe('AccessControl - Smart Contract', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let bob: HardhatEthersSigner;

	let stablecoin: Stablecoin;

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
	});

	describe('Basic checks for deployment', () => {
		it('should return the correct name and symbol', async () => {
			expect(await stablecoin.name()).to.equal('Wryt USD');
			expect(await stablecoin.symbol()).to.equal('wyUSD');
		});

		it('should return an address for votes and savings', async () => {
			expect(await stablecoin.votes()).to.not.equal(ethers.ZeroAddress);
			expect(await stablecoin.savings()).to.not.equal(ethers.ZeroAddress);
		});
	});

	describe('Module Management and Minting', () => {
		it('should set alice as module and allow minting', async () => {
			// Set alice as module
			await stablecoin.setModule(alice.address, 'true');
			expect(await stablecoin.isModule(alice.address)).to.be.true;

			// Mint tokens using alice as module
			const mintAmount = ethers.parseEther('1000');
			await stablecoin.connect(alice).mint(alice.address, mintAmount);
			expect(await stablecoin.balanceOf(alice.address)).to.equal(mintAmount);
		});

		it('should revert when bob tries to set module', async () => {
			// Bob is not owner, should fail to set module
			await expect(stablecoin.connect(bob).setModule(bob.address, 'true')).to.be.revertedWithCustomError(
				stablecoin,
				'OwnableUnauthorizedAccount'
			);
		});
	});
});
