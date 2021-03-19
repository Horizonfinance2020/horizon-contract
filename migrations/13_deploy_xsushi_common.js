const HGateKeeperFactory = artifacts.require("HGateKeeperFactory");
const HGateKeeper = artifacts.require("HGateKeeper");
const HDispatcherFactory = artifacts.require("HDispatcherFactory");
const HDispatcher = artifacts.require("HDispatcher");
const AddressArray = artifacts.require("AddressArray")
//const USDT = artifacts.require("USDT");
const StdERC20 = artifacts.require("StdERC20");
const TrustListFactory = artifacts.require("TrustListFactory");
const TrustList = artifacts.require("TrustList");
const MockYieldStreamFactory = artifacts.require("MockYieldStreamFactory");
const MockYieldStream = artifacts.require("MockYieldStream");
const SafeERC20 = artifacts.require("SafeERC20");
const SafeMath = artifacts.require("SafeMath");
const TokenBank = artifacts.require("TokenBank");
const TokenBankFactory = artifacts.require("TokenBankFactory");
const HPeriodTokenFactory = artifacts.require("HPeriodTokenFactory");
const HPeriodToken = artifacts.require("HPeriodToken");

const HEnvFactory = artifacts.require("HEnvFactory");
const HEnv = artifacts.require("HEnv");

const HToken = artifacts.require("HToken");
const HTokenFactory = artifacts.require("HTokenFactory");
const yUSDStream = artifacts.require("yUSDStream");
const xSushiStream = artifacts.require("xSushiStream")

const fs = require("fs");

async function performMigration(deployer, network, accounts) {

  const data = fs.readFileSync(network + '-yusd-common.json', 'utf-8');
  const common = JSON.parse(data.toString());
  dispatcher = await HDispatcher.at(common["Dispatcher"])

  brief = {}

  brief["network"] = network;

  brief["Dispatcher"] = dispatcher.address
  if(network.includes("main")){
    s = await SafeMath.deployed();

    await deployer.link(SafeMath, xSushiStream);
    await deployer.deploy(xSushiStream);
    xsushistream = await xSushiStream.deployed();
    brief["xSuishi Stream"] = xsushistream.address;
    brief["SafeMath"] = s.address;

    token = await xsushistream.target_token();
    await dispatcher.resetYieldStream(token, xsushistream.address);

    brief["xSushi Stream Token"] = token
    stream_token = token

    console.log("creating trust list...");
    tlfactory = await TrustListFactory.deployed();
    tokentx = await tlfactory.createTrustList(['0x0000000000000000000000000000000000000000']);
    gas_pool_tlist = await TrustList.at(tokentx.logs[0].args.addr);
    tokentx = await tlfactory.createTrustList(['0x0000000000000000000000000000000000000000']);
    fee_pool_tlist = await TrustList.at(tokentx.logs[0].args.addr);


    console.log("creating token bank...");
    tkfactory = await TokenBankFactory.deployed();
    tx = await tkfactory.newTokenBank("Horizon Fee Pool", stream_token, fee_pool_tlist.address);
    fee_pool = await TokenBank.at(tx.logs[0].args.addr);

    brief["Fee pool trust list"] = fee_pool_tlist.address;
    brief['Fee pool'] = fee_pool.address;

    console.log("creating env...");
    envfactory = await HEnvFactory.deployed();
    tx = await envfactory.createHEnv(stream_token);
    env = await HEnv.at(tx.logs[0].args.addr);
    await env.changeFeePoolAddr(fee_pool.address);
    brief["Env"] = env.address;
  }


  for(var key in brief){
    console.log(key, " ", brief[key]);
  }
// write JSON string to a file
  const ndata = JSON.stringify(brief);
  await fs.writeFile(network+'-xsushi-common.json', ndata, (err) => {
    if (err) {
        throw err;
    }
    console.log("JSON data is saved.");
  });
}

module.exports = function(deployer, network, accounts){
deployer
    .then(function() {
      return performMigration(deployer, network, accounts)
    })
    .catch(error => {
      console.log(error)
      process.exit(1)
    })
};
