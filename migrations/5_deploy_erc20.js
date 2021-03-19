const ERC20TokenFactory = artifacts.require("ERC20TokenFactory");
const AddressArray = artifacts.require("AddressArray");
const SafeMath = artifacts.require("SafeMath");

async function performMigration(deployer, network, accounts) {
    await AddressArray.deployed();
  await SafeMath.deployed();
    await deployer.link(AddressArray, ERC20TokenFactory);
  await deployer.link(SafeMath, ERC20TokenFactory);
    await deployer.deploy(ERC20TokenFactory);
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
