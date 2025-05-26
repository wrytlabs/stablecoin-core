import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { storeConstructorArgs } from '../../helper/store.args';
import { ADDRESS } from '../../exports/address.testnet.config';
import { Address } from 'viem';
import { mainnet, polygon } from 'viem/chains';

// config and select
export const NAME: string = 'Stablecoin'; // <-- select smart contract
export const FILE: string = 'StablecoinUSD'; // <-- name exported file
export const MOD: string = NAME + 'Module';
console.log(NAME);

// params
export type DeploymentParams = {
	name: string;
	symbol: string;
	dao: Address;
};

export const params: DeploymentParams = {
	name: 'WrytLabs Stable USD',
	symbol: 'wySUSD',
	dao: ADDRESS[polygon.id].dao,
};

export type ConstructorArgs = [string, string, Address];

export const args: ConstructorArgs = [params.name, params.symbol, params.dao];

console.log('Imported Params:');
console.log(params);

// export args
storeConstructorArgs(FILE, args);
console.log('Constructor Args');
console.log(args);

// fail safe
// process.exit();

export default buildModule(MOD, (m) => {
	return {
		[NAME]: m.contract(NAME, args),
	};
});
