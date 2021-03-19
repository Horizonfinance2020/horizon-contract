const TokenBankFactory = artifacts.require("TokenBankFactory");

module.exports = function(deployer) {
  deployer.deploy(TokenBankFactory);
};
