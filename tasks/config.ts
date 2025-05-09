export enum Network {
  mainnet = "mainnet",
  sepolia = "sepolia",
  apechain = "apechain",
  curtis = "curtis",
}

export interface Params<T> {
  [Network.mainnet]: T;
  [Network.sepolia]: T;
  [Network.apechain]: T;
  [Network.curtis]: T;
}

export const getParams = <T>({ mainnet, sepolia, apechain, curtis }: Params<T>, network: string): T => {
  network = Network[network as keyof typeof Network];
  switch (network) {
    case Network.mainnet:
      return mainnet;
    case Network.sepolia:
      return sepolia;
    case Network.curtis:
      return curtis;
    case Network.apechain:
      return apechain;
    default:
      return curtis;
  }
};

const INFURA_KEY = process.env.INFURA_KEY || "";
const ALCHEMY_KEY = process.env.ALCHEMY_KEY || "";

export const NETWORKS_RPC_URL: Params<string> = {
  [Network.mainnet]: ALCHEMY_KEY
    ? `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`
    : `https://mainnet.infura.io/v3/${INFURA_KEY}`,
  [Network.sepolia]: ALCHEMY_KEY
    ? `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}`
    : `https://sepolia.infura.io/v3/${INFURA_KEY}`,
  [Network.apechain]: "https://rpc.apechain.com/http",
  [Network.curtis]: "https://curtis.rpc.caldera.xyz/http",
};

export const FEE: Params<string> = {
  [Network.mainnet]: "400",
  [Network.sepolia]: "400",
  [Network.apechain]: "400",
  [Network.curtis]: "400",
};

export const FEE_RECIPIENT: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x5F532d6D901fF6591652355Ed5769AD414E6c6cb",
  [Network.curtis]: "0xafF5C36642385b6c7Aaf7585eC785aB2316b5db6",
};

export const WAPE_COIN: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x48b62137EdfA95a428D35C09E44256a739F6B557",
  [Network.curtis]: "0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b",
};

export const BEACON: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x00000000000087c6dbaDC090d39BC10316f20658",
  [Network.curtis]: "0x52912571414Db261E4122B0658037122dAe9718C",
};

export const APE_STAKING: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x4ba2396086d52ca68a37d9c0fa364286e9c7835a",
  [Network.curtis]: "0x5350A3FFEDCb50775f425982a11E31E2Ba43F34B",
};

export const BAYC: Params<string> = {
  [Network.mainnet]: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
  [Network.sepolia]: "0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B",
  [Network.apechain]: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
  [Network.curtis]: "0x52f51701ed1B560108fF71862330f9C8b4a15c8e",
};

export const MAYC: Params<string> = {
  [Network.mainnet]: "0x60E4d786628Fea6478F785A6d7e704777c86a7c6",
  [Network.sepolia]: "0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC",
  [Network.apechain]: "0x60E4d786628Fea6478F785A6d7e704777c86a7c6",
  [Network.curtis]: "0x35e13d4545Dd3935F87a056495b5Bae4f3aB9049",
};

export const BAKC: Params<string> = {
  [Network.mainnet]: "0xba30E5F9Bb24caa003E9f2f0497Ad287FDF95623",
  [Network.sepolia]: "0xE8636AFf2F1Cf508988b471d7e221e1B83873FD9",
  [Network.apechain]: "0xba30E5F9Bb24caa003E9f2f0497Ad287FDF95623",
  [Network.curtis]: "0xFe94A8d9260a96e6da8BD6BfA537b49E73791567",
};

export const DELEAGATE_CASH: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x0000000000000000000000000000000000000000",
  [Network.curtis]: "0x0000000000000000000000000000000000000000",
};

export const DELEAGATE_CASH_V2: Params<string> = {
  [Network.mainnet]: "0x00000000000000447e69651d841bD8D104Bed493",
  [Network.sepolia]: "0x00000000000000447e69651d841bD8D104Bed493",
  [Network.apechain]: "",
  [Network.curtis]: "",
};

export const BNFT_REGISTRY: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0xcAbe4E00a44Ff38990A42f43312d470DE5796FA6",
  [Network.curtis]: "0xc31078cC745daE8f577EdBa2803405CE571cb9f8",
};

export const AAVE_ADDRESS_PROVIDER: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "",
  [Network.curtis]: "",
};

export const BEND_ADDRESS_PROVIDER: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "",
  [Network.curtis]: "",
};

export const BAYC_REWARDS_SHARE_RATIO: Params<string> = {
  [Network.mainnet]: "5000",
  [Network.sepolia]: "5000",
  [Network.apechain]: "5000",
  [Network.curtis]: "5000",
};

export const MAYC_REWARDS_SHARE_RATIO: Params<string> = {
  [Network.mainnet]: "5000",
  [Network.sepolia]: "5000",
  [Network.apechain]: "5000",
  [Network.curtis]: "5000",
};

export const BAKC_REWARDS_SHARE_RATIO: Params<string> = {
  [Network.mainnet]: "5000",
  [Network.sepolia]: "5000",
  [Network.apechain]: "5000",
  [Network.curtis]: "5000",
};

export const STAKER_MANAGER_V1: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "",
  [Network.curtis]: "",
};

export const COIN_POOL_V1: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "",
  [Network.curtis]: "",
};

export const BENDV2_ADDRESS_PROVIDER: Params<string> = {
  [Network.mainnet]: "",
  [Network.sepolia]: "",
  [Network.apechain]: "0x0000000000000000000000000000000000000000",
  [Network.curtis]: "0x0000000000000000000000000000000000000000",
};
