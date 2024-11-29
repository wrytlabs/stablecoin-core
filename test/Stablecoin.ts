import { expect } from 'chai';
import { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { Governance, Savings, Stablecoin } from '../typechain';
import { ZeroAddress } from 'ethers';

describe('Stablecoin - Smart Contract', () => {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let bob: HardhatEthersSigner;
	let module: HardhatEthersSigner;

	let stablecoin: Stablecoin;
	let votes: Governance;
	let savings: Savings;

	beforeEach(async () => {
		[owner, alice, bob, module] = await ethers.getSigners();

		const Stablecoin = await ethers.getContractFactory('Stablecoin');
		stablecoin = await Stablecoin.deploy(
			'Wryt USD',
			'wyUSD',
			20_000, // 20% votesQuorumPPM
			90, // 90 votesActivateDays
			0, // 0% savingsQuorumPPM
			3 // 3 savingsActivateDays
		);

		votes = await ethers.getContractAt('Governance', await stablecoin.votes());
		savings = await ethers.getContractAt('Savings', await stablecoin.votes());
	});

	describe('Deployment', () => {
		it('Should set correct token metadata', async () => {
			expect(await stablecoin.name()).to.equal('Wryt USD');
			expect(await stablecoin.symbol()).to.equal('wyUSD');
		});

		it('Should deploy governance and savings contracts', async () => {
			expect(await stablecoin.votes()).to.not.equal(ethers.ZeroAddress);
			expect(await stablecoin.savings()).to.not.equal(ethers.ZeroAddress);
		});
	});

	describe('Module Management', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Initial module');
		});

		it('Should allow setting initial module', async () => {
			expect(await stablecoin.isModule(module.address)).to.be.true;
			expect(await stablecoin.checkModule(module.address)).to.be.true;
		});

		it('Should revert setting module after supply exists', async () => {
			// await stablecoin.setModule(module.address, 'Initial module');
			await stablecoin.connect(module).mint(alice.address, 100);
			await expect(stablecoin.setModule(bob.address, 'Should fail')).to.be.revertedWithCustomError(
				stablecoin,
				'NotAvailable'
			);
		});
	});

	describe('Minting', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Initial module');
		});

		it('Should allow module to mint', async () => {
			await stablecoin.connect(module).mint(alice.address, 1000);
			expect(await stablecoin.balanceOf(alice.address)).to.equal(1000);
		});

		it('Should revert mint to zero address', async () => {
			await expect(stablecoin.connect(module).mint(ethers.ZeroAddress, 1000)).to.be.revertedWithCustomError(
				stablecoin,
				'NoChange'
			);
		});

		it('Should revert mint from non-module', async () => {
			await expect(stablecoin.connect(bob).mint(alice.address, 1000))
				.to.be.revertedWithCustomError(stablecoin, 'NotModule')
				.withArgs(bob.address);
		});
	});

	describe('Flow Management', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, 1000);
		});

		describe('Inflow', () => {
			it('Should handle pure inflow', async () => {
				await stablecoin.connect(module).declareInflow(alice.address, 500);
				expect(await stablecoin.totalInflow()).to.equal(500);
			});

			it('Should handle inflow with existing outflow', async () => {
				await stablecoin.connect(module).declareOutflow(bob.address, 300);
				await stablecoin.connect(module).declareInflow(alice.address, 200);
				expect(await stablecoin.totalOutflowMinted()).to.equal(100);
			});
		});

		describe('Outflow', () => {
			it('Should handle pure outflow', async () => {
				await stablecoin.connect(module).declareOutflow(bob.address, 500);
				expect(await stablecoin.totalOutflowCovered()).to.equal(0);
				expect(await stablecoin.totalOutflowMinted()).to.equal(500);
			});

			it('Should handle outflow with savings', async () => {
				// Setup savings first
				await stablecoin.connect(module).declareInflow(alice.address, 300);
				await stablecoin.connect(module).declareOutflow(bob.address, 200);
				expect(await stablecoin.totalOutflowCovered()).to.equal(200);
				expect(await stablecoin.totalOutflowMinted()).to.equal(0);
			});

			it('Should handle outflow with savings and mint', async () => {
				// Setup savings first
				await stablecoin.connect(module).declareInflow(alice.address, 1000);
				await stablecoin.connect(module).declareOutflow(bob.address, 1200);
				expect(await stablecoin.totalOutflowCovered()).to.equal(1000);
				expect(await stablecoin.totalOutflowMinted()).to.equal(200);
			});
		});
	});

	describe('ERC20 Extensions', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
		});

		it('Should give infinite allowance to modules', async () => {
			expect(await stablecoin.connect(module).allowance(alice.address, bob.address)).to.equal(ethers.MaxUint256);
		});
	});

	describe('Edge Cases', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
		});

		it('Should handle zero value operations', async () => {
			await expect(stablecoin.connect(module).declareInflow(alice.address, 0)).to.be.revertedWithCustomError(
				stablecoin,
				'NoChange'
			);
			await expect(stablecoin.connect(module).declareInflow(ZeroAddress, 1)).to.be.revertedWithCustomError(
				stablecoin,
				'NoChange'
			);

			await expect(stablecoin.connect(module).declareOutflow(alice.address, 0)).to.be.revertedWithCustomError(
				stablecoin,
				'NoChange'
			);
			await expect(stablecoin.connect(module).declareOutflow(ZeroAddress, 1)).to.be.revertedWithCustomError(
				stablecoin,
				'NoChange'
			);
		});

		it('Should handle maximum values', async () => {
			const maxUint256 = ethers.MaxUint256;
			await stablecoin.connect(module).mint(alice.address, maxUint256);
			expect(await stablecoin.balanceOf(alice.address)).to.equal(maxUint256);
		});
	});
});
