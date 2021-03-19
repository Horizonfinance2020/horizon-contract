const SafeMath = artifacts.require("SafeMath");
const AddressArray = artifacts.require("AddressArray");
const Address = artifacts.require("Address");
const SafeERC20 = artifacts.require("SafeERC20");

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.deploy(AddressArray);
  deployer.deploy(Address);
  deployer.deploy(SafeERC20);
};
