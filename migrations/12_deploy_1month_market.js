const fs = require("fs");
const HGateKeeperFactory = artifacts.require("HGateKeeperFactory");
const HGateKeeper = artifacts.require("HGateKeeper");
const HPeriodTokenFactory = artifacts.require("HPeriodTokenFactory");
const HPeriodToken = artifacts.require("HPeriodToken");
const HToken = artifacts.require("HToken");
const HTokenFactory = artifacts.require("HTokenFactory");
const TrustList = artifacts.require("TrustList");

async function performMigration(deployer, network, accounts) {
  const data = fs.readFileSync(network + '-yusd-common.json', 'utf-8');
  const common = JSON.parse(data.toString());

  if(network.includes("ropsten") ||
  network.includes("ganache")){
    start_block = 123456;
    period = 100;
    gap = 20;
  }else if(network.includes("main")){
    start_block = 11690000;
    period = 181362;
    gap = 5960;
  }

  brief = {}
  brief["network"] = network
  brief["Start Block"] = start_block
  brief["Period"] = period
  brief["Gap"] = gap

  stream_token = common["Stream Token"]
  env = common["Env"]
  dispatcher = common["Dispatcher"]
  fee_pool_addr = common["Fee pool"]

  console.log("creating for 1 week yusd market");

  console.log("creating period token...");
  hptfactory = await HPeriodTokenFactory.deployed();
  htfactory = await HTokenFactory.deployed();
  tx = await hptfactory.createPeriodToken(stream_token, start_block, period, gap, htfactory.address);
  hpt = await HPeriodToken.at(tx.logs[0].args.addr);
  brief["HPeriodToken"] = hpt.address;

  console.log("creating gate keeper...");
  gatekeeper_factory = await HGateKeeperFactory.deployed();
  tx = await gatekeeper_factory.createGateKeeperForPeriod(env, dispatcher, hpt.address);
  gatekeeper = await HGateKeeper.at(tx.logs[2].args.addr)
  brief["HGateKeeper"] = gatekeeper.address;

  console.log("transfer ownership...");
  await hpt.transferOwnership(gatekeeper.address);
  //await gas_pool.transferOwnership(gatekeeper.address);

  if(network.includes("main")){
    console.log("setting up support ratio");
    await gatekeeper.resetSupportRatios([416666, 833333, 1250000, 1666666, 2083333, 2500000, 2916666, 3333333, 3750000, 4166666, 4583333, 5000000, 5416666, 5833333, 6250000, 6666666, 7083333, 7500000, 7916666, 8333333])
    console.log("setting yield interest pool")
    await gatekeeper.changeYieldPool(fee_pool_addr);
  }

  const wdata = JSON.stringify(brief);
  await fs.writeFile(network+'-1month-yusd.json', wdata, (err) => {
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
