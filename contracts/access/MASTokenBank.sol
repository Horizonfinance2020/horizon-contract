pragma solidity >=0.4.21 <0.6.0;
pragma solidity >=0.4.21 <0.6.0;

import "../MultiSigTools.sol";

contract TokenBankInterface{
  function claimStdTokens(address _token, address payable to) public;
  function transfer(address payable to, uint tokens) public returns (bool success);

  function transferOwnership(address newOwner) public;
}

contract MASTokenBank is MultiSigTools{
  TokenBankInterface private _token_bank;

  constructor(address _tl, address _multisig) MultiSigTools(_multisig) public{
    _token_bank = TokenBankInterface(_tl);
  }

  function claimStdTokens(uint64 id, address _token, address payable to) public
    only_signer
    is_majority_sig(id, "claimStdTokens"){
      _token_bank.claimStdTokens(_token, to);
    }

  function transfer(uint64 id, address payable to, uint tokens) public
    only_signer
    is_majority_sig(id, "transfer")returns (bool success){
      return _token_bank.transfer(to, tokens);
  }

  function transferOwnership(uint64 id, address newOwner)
    public only_signer is_majority_sig(id, "transferOwnership"){
    _token_bank.transferOwnership(newOwner);
  }

}

contract MASTokenBankFactory{
  event NewMASTokenBank(address addr);
  function createMASTokenBank(address _tl, address _multisig) public returns(address){
    MASTokenBank mtb = new MASTokenBank(_tl, _multisig);
    emit NewMASTokenBank(address(mtb));
    return address(mtb);
  }
}
