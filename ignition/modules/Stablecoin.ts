import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { getChildFromSeed } from '../../helper/wallet';
import { storeConstructorArgs } from '../../helper/store.args';
import { network } from 'hardhat';

const seed = process.env.DEPLOYER_SEED;
if (!seed) throw new Error('Failed to import the seed string from .env');

const w1 = getChildFromSeed(seed, 1); // admin

console.log('Config Info: Deploying Module with accounts');
console.log(w1.address);

// constructor args
export const args = ['Wryt USD', 'wyUSD', 200_000, 90, 0, 3];
storeConstructorArgs('MembershipModule', args, true);

console.log('Constructor Args');
console.log(args);

const StablecoinModule = buildModule('MembershipModule', (m) => {
	// @dev: for runtime specific network tasks
	// const chainId = hardhat.network.config.chainId;
	// const params = PARAM[chainId].param01;
	// const addr = ADDRESS[chainId].contractDeployedAddress;

	// Deploy Membership contract
	const stablecoin = m.contract('Stablecoin', args);

	// You can add more tx logic here
	m.call(stablecoin, 'setModule', [w1.address, 'Deployer']);

	return {
		stablecoin,
	};
});

export default StablecoinModule;
