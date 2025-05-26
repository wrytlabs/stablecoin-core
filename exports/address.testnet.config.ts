import { polygon } from 'viem/chains';
import { Address } from 'viem';

export interface ChainAddress {
	[polygon.id]: {
		// core
		dao: Address;
		daoToken: Address;

		// stablecoin
		stablecoinUSD: Address;
	};
}

export const ADDRESS: ChainAddress = {
	[polygon.id]: {
		// core
		dao: '0x99aD438bF4a4691704721B0cBAa78D920160828a',
		daoToken: '0x58b9f8cD55f3a408e462B9e930a0e072b442a070',

		// stablecoin
		stablecoinUSD: '0x891e48c62c5A4819CA6fF935efF6B09E218B627d',
	},
};
