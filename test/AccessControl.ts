import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { Governance, Stablecoin } from '../typechain';
import { formatUnits } from 'ethers';

describe('AccessControl - Smart Contract', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let bob: HardhatEthersSigner;
	let module: HardhatEthersSigner;

	let stablecoin: Stablecoin;
	let votes: Governance;

	before('Should deploy Stablecoin with correct parameters', async () => {
		[owner, alice, bob, module] = await ethers.getSigners();

		const Stablecoin = await ethers.getContractFactory('Stablecoin');
		stablecoin = await Stablecoin.deploy(
			'Wryt USD', // name
			'wyUSD', // symbol
			20_000, // 20% votesQuorumPPM
			90, // 90 votesActivateDays
			0, // 0% savingsQuorumPPM
			3 // 3 savingsActivateDays
		);

		votes = await ethers.getContractAt('Governance', await stablecoin.votes());
	});

	// ---------------------------------------------------------------------------------------

	describe('Constants', () => {
		it('Should have correct CAN_ACTIVATE_DELAY value', async () => {
			expect(await stablecoin.CAN_ACTIVATE_DELAY()).to.equal(30 * 24 * 60 * 60); // 30 days
		});

		it('Should have correct ACTIVATION_DURATION value', async () => {
			expect(await stablecoin.ACTIVATION_DURATION()).to.equal(2 * 365 * 24 * 60 * 60); // 2 years
		});

		it('Should have correct ACTIVATION_MULTIPLIER value', async () => {
			expect(await stablecoin.ACTIVATION_MULTIPLIER()).to.equal(3);
		});
	});

	// ---------------------------------------------------------------------------------------

	describe('checkOnlyCoin', () => {
		it("returns true when checking contract's own address", async () => {
			const result = await stablecoin.checkOnlyCoin(await stablecoin.getAddress());
			expect(result).to.be.true;
		});

		it('returns false when checking any other address', async () => {
			expect(await stablecoin.checkOnlyCoin(alice)).to.be.false;
			expect(await stablecoin.checkOnlyCoin(module)).to.be.false;
		});
	});

	describe('verifyOnlyCoin', () => {
		it('succeeds when called by contract itself', async () => {
			await expect(stablecoin.verifyOnlyCoin(await stablecoin.getAddress())).to.not.be.reverted;
		});

		it('reverts when called by other address', async () => {
			await expect(stablecoin.verifyOnlyCoin(module))
				.to.be.revertedWithCustomError(stablecoin, 'NotCoin')
				.withArgs(module.address);
		});
	});

	// ---------------------------------------------------------------------------------------

	describe('Module Default Guards', () => {
		it('returns false when checking isModule as default', async () => {
			expect(await stablecoin.isModule(module)).to.be.false;
		});

		it('returns 0 when checking moduleActivation as default', async () => {
			expect(await stablecoin.moduleActivation(module)).to.be.equal(0);
		});

		it('returns false when checking moduleExpiration as default', async () => {
			expect(await stablecoin.moduleExpiration(module)).to.be.equal(0);
		});

		it('returns false when checking checkModule as default', async () => {
			expect(await stablecoin.checkModule(module)).to.be.false;
		});

		it('revert when checking verifyModule as default', async () => {
			await expect(stablecoin.verifyModule(module))
				.to.be.revertedWithCustomError(stablecoin, 'NotModule')
				.withArgs(module.address);
		});
	});

	// ---------------------------------------------------------------------------------------

	describe('Module Initial Config Process', () => {
		it('Should set correct module values when totalSupply is 0', async () => {
			await stablecoin.setModule(module.address, 'Initial module setup');
			const currentTimestamp = await time.latest();

			expect(await stablecoin.isModule(module.address)).to.be.true;
			expect(await stablecoin.moduleActivation(module.address)).to.equal(currentTimestamp);
			expect(await stablecoin.moduleExpiration(module.address)).to.equal(ethers.MaxUint256);
		});

		it('Should set multiple module when totalSupply is 0', async () => {
			await stablecoin.setModule(owner.address, 'Initial module A');
			await stablecoin.setModule(alice.address, 'Initial module B');
			await stablecoin.setModule(module.address, 'Initial module C');
		});

		it('Should revert when trying to set module with non-zero totalSupply', async () => {
			await stablecoin.setModule(module.address, 'Initial module setup');
			await stablecoin.connect(module).mint(module.address, ethers.parseEther('1'));

			await expect(stablecoin.setModule(alice.address, 'Should fail')).to.be.revertedWithCustomError(
				stablecoin,
				'NotAvailable'
			);
		});
	});

	describe('Module Voting Process', () => {
		it('Should revert configModule when votes not yet activated', async () => {
			await votes.connect(module).delegate(module.address);
			await stablecoin.mint(module.address, ethers.parseEther('1000'));

			await expect(
				stablecoin.connect(module).configModule(bob.address, true, 'Too early')
			).to.be.revertedWithCustomError(stablecoin, 'NotPassedDuration');
		});

		it('Should allow configModule after votes accumulation period', async () => {
			// Wait for votes activation
			await time.increase(90 * 24 * 60 * 60 + 1); // 90 days + 1 second

			// Should now succeed
			await stablecoin.connect(module).configModule(bob, true, 'Activate alice');
			expect(await stablecoin.moduleActivation(bob)).to.be.gt(0);
			expect(await stablecoin.isModule(bob)).to.be.true;
		});
	});

	// ---------------------------------------------------------------------------------------

	// internal function can not be tested, only with qualified access via stablecoin:configModule
	// passed voting powers for module
	describe('Module Management', () => {
		it('Should correctly activate a new module', async () => {
			expect(await stablecoin.checkModule(bob)).to.be.false;
			await time.increase(30 * 24 * 60 * 60 + 1); // activation period
			expect(await stablecoin.checkModule(bob)).to.be.true;
		});

		it('Should revert an active module to extent serve time, by serving less den 50%', async () => {
			await expect(
				stablecoin.connect(module).configModule(bob, true, 'Extend serve, revert')
			).to.revertedWithCustomError(stablecoin, 'NotServed');
		});

		it('Should extend expiration for active modules', async () => {
			const initialExpiration = await stablecoin.moduleExpiration(bob);
			await time.increase(400 * 24 * 60 * 60 + 1); // wait more den 50% of two years

			await stablecoin.connect(module).configModule(bob, true, 'Extend module');
			expect(await stablecoin.moduleExpiration(module)).to.be.gt(initialExpiration);
		});

		it('Should be extended with the correct served multiplyer', async () => {
			const activation = await stablecoin.moduleActivation(bob);
			const expiration = await stablecoin.moduleExpiration(bob);
			const currentTimestamp = await time.latest();

			const served = currentTimestamp - parseInt(activation.toString());
			const extention = parseInt(expiration.toString()) - currentTimestamp;

			expect(served * 2.9).to.be.lessThan(extention);
			expect(served * 3).to.be.greaterThanOrEqual(extention);
		});

		it('Should expire module gracefully', async () => {
			await stablecoin.connect(module).configModule(bob, false, 'Disable module');

			await time.increase(30 * 24 * 60 * 60 + 1); // wait 30days

			expect(await stablecoin.checkModule(bob)).to.be.false;

			const currentTimestamp = await time.latest();
			expect(await stablecoin.moduleExpiration(bob)).to.be.lessThan(currentTimestamp);
		});

		it('Should configModule and revert before activation', async () => {
			await stablecoin.connect(module).configModule(bob, true, 'Gracfully activate module');

			const activation = await stablecoin.moduleActivation(bob);
			const expiration = await stablecoin.moduleExpiration(bob);

			await stablecoin.connect(module).configModule(bob, false, 'Deny module in grace activation');

			expect(await stablecoin.moduleExpiration(bob)).to.be.lessThan(expiration);
			expect(await stablecoin.moduleExpiration(bob)).to.be.eq(activation);
		});
	});
});
