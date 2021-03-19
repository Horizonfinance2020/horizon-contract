const HGateKeeperFactory = artifacts.require("HGateKeeperFactory");
const HDispatcherFactory = artifacts.require("HDispatcherFactory");
const AddressArray = artifacts.require("AddressArray")
const SafeERC20 = artifacts.require("SafeERC20");
const SafeMath = artifacts.require("SafeMath");
const HEnvFactory = artifacts.require("HEnvFactory");
const HTokenFactory = artifacts.require("HTokenFactory");
const HPeriodTokenFactory = artifacts.require("HPeriodTokenFactory");



async function performMigration(deployer, network, accounts) {
  await deployer.deploy(HEnvFactory);


  await deployer.link(SafeMath, HGateKeeperFactory);
  await deployer.link(SafeERC20, HGateKeeperFactory);
  await deployer.deploy(HGateKeeperFactory);

  //await deployer.link(SafeMath, HDispatcherFactory);
  await deployer.link(SafeERC20, HDispatcherFactory);
  await deployer.deploy(HDispatcherFactory);


  await deployer.link(SafeMath, HTokenFactory);
  await deployer.link(SafeERC20, HTokenFactory);
  await deployer.deploy(HTokenFactory);


  await deployer.link(SafeMath, HPeriodTokenFactory);
  await deployer.link(SafeERC20, HPeriodTokenFactory);
  await deployer.deploy(HPeriodTokenFactory);

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
