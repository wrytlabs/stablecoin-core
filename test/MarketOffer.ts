import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { MarketOffer, MarketOffer__factory, TestToken } from '../typechain';
import { getAddress, parseEther, ZeroAddress } from 'ethers';
import { expect } from 'chai';

describe('MerketOffer - Smart Contract', function () {
	let owner: HardhatEthersSigner;
	let alice: HardhatEthersSigner;
	let bob: HardhatEthersSigner;

	let a: TestToken;
	let b: TestToken;
	let c: TestToken;
	let market: MarketOffer;
	let offer: Awaited<ReturnType<MarketOffer['offers']>>;

	let price = parseEther('2');
	let amount = parseEther('100');
	let minAmount = parseEther('10');

	beforeEach('Should deploy with correct parameters', async () => {
		[owner, alice, bob] = await ethers.getSigners();

		const TestTokenA = await ethers.getContractFactory('TestToken');
		a = await TestTokenA.deploy(
			'tokenA', // name
			'TKNa' // symbol
		);

		const TestTokenB = await ethers.getContractFactory('TestToken');
		b = await TestTokenB.deploy(
			'tokenB', // name
			'TKNb' // symbol
		);

		const TestTokenC = await ethers.getContractFactory('TestToken');
		c = await TestTokenC.deploy(
			'tokenC', // name
			'TKNc' // symbol
		);

		// Get Savings contract instance
		const Market = await ethers.getContractFactory('MarketOffer');
		market = await Market.deploy(
			'wyMarket', // name
			'wyMKT' // symbol
		);

		await a.connect(alice).mint();
		await a.connect(alice).approve(await market.getAddress(), amount);

		await b.connect(bob).mint();
		await b.connect(bob).approve(await market.getAddress(), (amount * price) / parseEther('1'));

		await c.connect(bob).mint();
		await c.connect(bob).approve(await market.getAddress(), amount);

		await market.connect(alice).createOffer(await a.getAddress(), await b.getAddress(), price, amount, minAmount);

		offer = await market.offers(1);
	});

	describe('Create Offer', () => {
		it('should have the correct maker address, owner', async () => {
			expect(offer.maker).to.be.eq(await alice.getAddress());
		});

		it('should have the correct tokenIn address', async () => {
			expect(offer.tokenIn).to.be.eq(await a.getAddress());
		});

		it('should have the correct tokenOut address', async () => {
			expect(offer.tokenOut).to.be.eq(await b.getAddress());
		});

		it('should have the correct price', async () => {
			expect(offer.price).to.be.eq(price);
		});

		it('should have should have the correct balance', async () => {
			expect(offer.amount).to.be.eq(amount);
		});

		it('balanceOf token a should be the same as amount in offer', async () => {
			expect(offer.amount).to.be.eq(await a.balanceOf(await market.getAddress()));
		});

		it('should have should have the correct min amount', async () => {
			expect(offer.minAmount).to.be.eq(minAmount);
		});
	});

	describe('Fill Offer', () => {
		it('to be reverted, wrong offer id', async () => {
			await expect(
				market
					.connect(bob)
					.fillOffer(100n, await bob.getAddress(), await bob.getAddress(), parseEther('10'), 0n)
			)
				.to.be.revertedWithCustomError(market, 'ERC721NonexistentToken')
				.withArgs(100n);
		});

		it('to be reverted, take: 0, give: 0 inputs', async () => {
			await expect(market.connect(bob).fillOffer(1n, await bob.getAddress(), await bob.getAddress(), 0n, 0n))
				.to.be.revertedWithCustomError(market, 'InvalidOffer')
				.withArgs(0, 0);
		});

		it('to be reverted, take: 91, left: 9, min: 10', async () => {
			await expect(
				market
					.connect(bob)
					.fillOffer(
						1n,
						await bob.getAddress(),
						await bob.getAddress(),
						amount - minAmount + parseEther('1'),
						0n
					)
			)
				.to.be.revertedWithCustomError(market, 'InvalidDust')
				.withArgs(minAmount - parseEther('1'), minAmount);
		});

		it('to be reverted, take: 101, left: -1, min: 10', async () => {
			await expect(
				market
					.connect(bob)
					.fillOffer(1n, await bob.getAddress(), await bob.getAddress(), amount + parseEther('1'), 0n)
			)
				.to.be.revertedWithCustomError(market, 'InvalidAmount')
				.withArgs(amount, amount + parseEther('1'));
		});

		it('expect partial fills', async () => {
			const bb = bob.address;

			const balAliceB = await b.balanceOf(alice.address);

			const balAlice = await a.balanceOf(alice.address);
			const balBob = await a.balanceOf(bob.address);

			await market.connect(bob).fillOffer(1n, bb, bb, amount / 2n, 0n);
			expect((await market.offers(1)).amount).to.be.eq(amount / 2n);

			const balAfterAlice = await a.balanceOf(alice.address);
			const balAfterBob = await a.balanceOf(bob.address);

			expect(balAfterAlice).to.be.eq(balAlice);
			expect(balAfterBob).to.be.eq(balBob + amount / 2n);

			await market.connect(bob).fillOffer(1n, bb, bb, amount / 5n, 0n);
			expect((await market.offers(1)).amount).to.be.eq((amount * 3n) / 10n);

			await market.connect(bob).fillOffer(1n, bb, bb, amount / 5n, 0n);
			expect((await market.offers(1)).amount).to.be.eq(amount / 10n);
			expect((await market.offers(1)).maker).to.not.eq(ZeroAddress);

			await market.connect(bob).fillOffer(1n, bb, bb, amount / 10n, 0n);
			expect((await market.offers(1)).amount).to.be.eq(0n);
			expect((await market.offers(1)).maker).to.be.eq(ZeroAddress);

			const balAliceAfterB = await b.balanceOf(alice.address);
			expect(balAliceAfterB).to.be.eq(balAliceB + (amount * price) / parseEther('1'));
		});
	});

	describe('Cancel Offer', () => {
		it('to be reverted, wrong owner', async () => {
			const bal = await a.balanceOf(bob.address);
			await expect(market.connect(bob).cancelOffer(1n, bob.address))
				.to.be.revertedWithCustomError(market, 'ERC721IncorrectOwner')
				.withArgs(bob.address, 1n, alice.address);

			const balAfter = await a.balanceOf(bob.address);
			expect(balAfter).to.be.eq(bal); // equal, not allowed to withdraw
		});

		it('correct owner cancels', async () => {
			const bal = await a.balanceOf(alice.address);
			await market.connect(alice).cancelOffer(1n, alice.address);
			const balAfter = await a.balanceOf(alice.address);

			expect(balAfter).to.be.eq(bal + amount);
		});
	});
});
