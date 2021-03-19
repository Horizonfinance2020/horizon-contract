const KeystoreProvider = require("truffle-keystore-provider")

const memoizeKeystoreProviderCreator = () => {
    let providers = {}

    return (account, dataDir, providerUrl) => {
        if (providerUrl in providers) {
            return providers[providerUrl]
        } else {
            const provider = new KeystoreProvider(account, dataDir, providerUrl)
            providers[providerUrl] = provider
            return provider
        }
    }
}

const createKeystoreProvider = memoizeKeystoreProviderCreator()

require('dotenv').config()

module.exports = {

  networks: {

    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    main: {
      provider : createKeystoreProvider(process.env.ACCOUNT, process.env.DATA_DIR, "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY),
      network_id: 1,
      gas: 5000000,
       confirmations: 2,    // # of confs to wait between deployments. (default: 0)
       timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
       //skipDryRun: true,     // Skip dry run before migrations? (default: false for public nets )
      gasPrice: 70000000000
    },

  },

  plugins: [
        'truffle-plugin-verify'
  ],

  api_keys: {
      etherscan: process.env.ETHERSCAN_API_KEY
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
       version: "0.5.10",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      //  evmVersion: "byzantium"
       }
    }
  }
}
