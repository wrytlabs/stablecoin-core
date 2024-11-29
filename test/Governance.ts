import { expect } from 'chai';
import { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { Governance, Savings, Stablecoin } from '../typechain';
import { ZeroAddress } from 'ethers';

describe('Governance - Smart Contract', () => {
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

	describe('Initialization', () => {
		it('Should set correct initial parameters', async () => {
			expect(await votes.name()).to.equal('Votes');
			expect(await votes.quorumPPM()).to.equal(20_000);
			expect(await votes.activateDays()).to.equal(90);
		});

		it('Should set correct coin reference', async () => {
			expect(await votes.coin()).to.equal(await stablecoin.getAddress());
		});
	});

	describe('Voting Power', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, ethers.parseEther('1000'));
		});

		it('Should track voting power after delegation', async () => {
			await votes.connect(alice).delegate(alice.address);
			expect(await votes.getVotes(alice.address)).to.equal(ethers.parseEther('1000'));
		});

		it('Should update voting power after transfer', async () => {
			await votes.connect(alice).delegate(alice.address);
			await stablecoin.connect(alice).transfer(bob.address, ethers.parseEther('400'));

			expect(await votes.getVotes(alice.address)).to.equal(ethers.parseEther('600'));
			await votes.connect(bob).delegate(bob.address);
			expect(await votes.getVotes(bob.address)).to.equal(ethers.parseEther('400'));
		});
	});

	describe('Activation Checks', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, ethers.parseEther('1000'));
			await votes.connect(alice).delegate(alice.address);
		});

		it('Should not allow activation before time period', async () => {
			await expect(votes.verifyCanActivate(alice.address)).to.be.revertedWithCustomError(votes, 'NotAvailable');
		});

		it('Should allow activation after time period', async () => {
			await time.increase(90 * 24 * 60 * 60 + 1); // 90 days + 1 second
			await expect(votes.verifyCanActivate(alice.address)).to.not.be.reverted;
		});

		it('Should enforce quorum requirements', async () => {
			await time.increase(90 * 24 * 60 * 60 + 1);

			// Mint more tokens to dilute Alice's voting power below quorum
			await stablecoin.connect(module).mint(bob.address, ethers.parseEther('5000'));

			await expect(votes.verifyCanActivate(alice.address)).to.be.revertedWithCustomError(votes, 'NotQualified');
		});
	});

	describe('Delegation Mechanics', () => {
		beforeEach(async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, ethers.parseEther('1000'));
		});

		it('Should track delegation history', async () => {
			await votes.connect(alice).delegate(bob.address);
			expect(await votes.delegates(alice.address)).to.equal(bob.address);
		});

		it('Should handle delegation changes', async () => {
			await votes.connect(alice).delegate(bob.address);
			await votes.connect(alice).delegate(alice.address);

			expect(await votes.delegates(alice.address)).to.equal(alice.address);
			expect(await votes.getVotes(bob.address)).to.equal(0);
			expect(await votes.getVotes(alice.address)).to.equal(ethers.parseEther('1000'));
		});
	});

	describe('Events', () => {
		it('Should emit DelegateChanged event', async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, ethers.parseEther('1000'));

			await expect(votes.connect(alice).delegate(bob.address))
				.to.emit(votes, 'DelegateChanged')
				.withArgs(alice.address, ethers.ZeroAddress, bob.address);
		});

		it('Should emit DelegateVotesChanged event', async () => {
			await stablecoin.setModule(module.address, 'Setup module');
			await stablecoin.connect(module).mint(alice.address, ethers.parseEther('1000'));

			await expect(votes.connect(alice).delegate(alice.address))
				.to.emit(votes, 'DelegateVotesChanged')
				.withArgs(alice.address, 0, ethers.parseEther('1000'));
		});
	});
});
