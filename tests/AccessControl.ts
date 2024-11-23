import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { Stablecoin } from '../typechain';

describe('AccessControl - Smart Contract', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let module: HardhatEthersSigner;

	let stablecoin: Stablecoin;

	before('Should deploy Stablecoin with correct parameters', async () => {
		[owner, alice, module] = await ethers.getSigners();

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
			await expect(stablecoin.connect(alice).verifyOnlyCoin(module)).to.be.revertedWithCustomError(
				stablecoin,
				'NotCoin'
			);
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
	});

	// ---------------------------------------------------------------------------------------

	// NotQualified
	// internal function can not be tested, only with qualified access via stablecoin:configModule

	// describe('Module Management', () => {
	// 	it('Should correctly activate a new module', async () => {
	// 		await stablecoin.configModule(module, true, 'Activate module');
	// 		expect(await stablecoin.isModule(module)).to.be.true;
	// 	});

	// 	it('Should enforce activation delay for new modules', async () => {
	// 		await stablecoin.configModule(module, true, 'Activate module');
	// 		expect(await stablecoin.checkModule(module)).to.be.false;

	// 		await time.increase(30 * 24 * 60 * 60 + 1); // 30 days + 1 second
	// 		expect(await stablecoin.checkModule(module)).to.be.true;
	// 	});

	// 	it('Should correctly deactivate an active module', async () => {
	// 		await stablecoin.configModule(module, true, 'Activate module');
	// 		await time.increase(30 * 24 * 60 * 60 + 1);

	// 		await stablecoin.configModule(module, false, 'Deactivate module');
	// 		await time.increase(30 * 24 * 60 * 60 + 1);
	// 		expect(await stablecoin.checkModule(module)).to.be.false;
	// 	});

	// 	it('Should extend expiration for active modules', async () => {
	// 		await stablecoin.configModule(module, true, 'Activate module');
	// 		await time.increase(30 * 24 * 60 * 60 + 1);

	// 		const initialExpiration = await stablecoin.moduleExpiration(module);
	// 		await time.increase(365 * 24 * 60 * 60); // 1 year

	// 		await stablecoin.configModule(module, true, 'Extend module');
	// 		expect(await stablecoin.moduleExpiration(module)).to.be.gt(initialExpiration);
	// 	});
	// });
});
