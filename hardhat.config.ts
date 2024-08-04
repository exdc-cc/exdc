import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const ALCHEMY_API_KEY = vars.get("ALCHEMY_API_KEY");

const PRIVATE_KEY = vars.get("PRIVATE_KEY");

const POLYGON_API_KEY = vars.get("ETHERSCAN_API_KEY");

const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_KEY");

const BSC_API_KEY = vars.get("BSC_API_KEY");

const config: HardhatUserConfig = {
  solidity: {
    compilers:[
      {
        version:"0.8.26",
        settings:{
          optimizer:{
            enabled:true, 
            runs:1200
          }
        }
      }
    ]
  },
  ignition: {
    strategyConfig: {
      create2: {
        // To learn more about salts, see the CreateX documentation
        salt: "0x0100100111110000100010000000000000000000000000000011011011000000",
      },
    },
  },
  networks: {
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId:1
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId:137
    },
    amoy:{
      url:`https://rpc-amoy.polygon.technology`,
      accounts:[PRIVATE_KEY],
      chainId:80002
    },
    zkSyncEra: {
      url:`https://zksync-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId:324
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: [PRIVATE_KEY]
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      polygon: POLYGON_API_KEY,
      amoy: ETHERSCAN_API_KEY,
      bsc: BSC_API_KEY,
      bscTestnet: BSC_API_KEY,
      mainnet: ETHERSCAN_API_KEY
    },
  },
};

export default config;
