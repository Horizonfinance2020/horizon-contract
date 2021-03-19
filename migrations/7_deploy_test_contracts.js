const TestAddressList = artifacts.require("TestAddressList");
const AddressArray = artifacts.require("AddressArray")
const TestTokenClaimer = artifacts.require("TestTokenClaimer");
const USDT = artifacts.require("USDT");
const StdERC20 = artifacts.require("StdERC20");
const TestERC20 = artifacts.require("TestERC20");
const MockYieldStreamFactory = artifacts.require("MockYieldStreamFactory");
const SafeERC20 = artifacts.require("SafeERC20");
const SafeMath = artifacts.require("SafeMath");


async function performMigration(deployer, network, accounts) {
  console.log("network is ", network);
  if(network.includes("development") ||
    network.includes("ganache")
    ){
    await AddressArray.deployed();
    await deployer.link(AddressArray, TestAddressList);
    await deployer.deploy(TestAddressList);
    await deployer.deploy(TestTokenClaimer);
    await deployer.link(SafeMath, USDT)
    await deployer.deploy(USDT);
    await deployer.deploy(StdERC20);
    await SafeMath.deployed();
    await deployer.link(SafeMath, TestERC20);
    await deployer.deploy(TestERC20, "TEST", 18, "TST");

    await deployer.link(SafeERC20, MockYieldStreamFactory);
    await deployer.link(SafeMath, MockYieldStreamFactory);
    await deployer.deploy(MockYieldStreamFactory);
  }
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
