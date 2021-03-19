const fs = require("fs");
const HGateKeeperFactory = artifacts.require("HGateKeeperFactory");
const HGateKeeper = artifacts.require("HGateKeeper");
const HPeriodTokenFactory = artifacts.require("HPeriodTokenFactory");
const HPeriodToken = artifacts.require("HPeriodToken");
const HToken = artifacts.require("HToken");
const HTokenFactory = artifacts.require("HTokenFactory");
const TrustList = artifacts.require("TrustList");

async function performMigration(deployer, network, accounts) {
  const data = fs.readFileSync(network + '-xsushi-common.json', 'utf-8');
  const common = JSON.parse(data.toString());

  if(network.includes("ropsten") ||
  network.includes("ganache")){
    start_block = 123456;
    period = 100;
    gap = 20;
  }else if(network.includes("main")){
    start_block = 12011000;
    period = 181362;
    gap = 5960;
  }

  brief = {}
  brief["network"] = network
  brief["Start Block"] = start_block
  brief["Period"] = period
  brief["Gap"] = gap

  stream_token = common["xSushi Stream Token"]
  env = common["Env"]
  dispatcher = common["Dispatcher"]
  fee_pool_addr = common["Fee pool"]

  console.log("creating for 1 month sushi market");

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
    await gatekeeper.resetSupportRatios([95890, 191780, 287671, 383561, 479452, 575342, 671232, 767123, 863013, 958904, 1054794, 1150684, 1246575, 1342465, 1438356, 1534246, 1630136, 1726027, 1821917, 1917808])
    console.log("setting yield interest pool")
    await gatekeeper.changeYieldPool(fee_pool_addr);
  }

  const wdata = JSON.stringify(brief);
  await fs.writeFile(network+'-18-1month-xsushi.json', wdata, (err) => {
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
