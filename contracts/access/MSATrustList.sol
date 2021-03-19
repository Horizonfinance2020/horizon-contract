pragma solidity >=0.4.21 <0.6.0;

import "../MultiSigTools.sol";

contract TrustListOpInterface{
  function add_trusted(address addr) public;
  function remove_trusted(address addr) public;

  function transferOwnership(address newOwner) public;
}

contract MSATrustList is MultiSigTools{

  TrustListOpInterface private _target_trust_list;

  constructor(address _tl, address _multisig) MultiSigTools(_multisig) public{
    _target_trust_list = TrustListOpInterface(_tl);
  }

  function target() public view returns(address){
    return address(_target_trust_list);
  }

  function add_trusted(uint64 id, address addr)
    public only_signer is_majority_sig(id, "add_trusted"){
    _target_trust_list.add_trusted(addr);
  }

  function remove_trusted(uint64 id, address addr)
    public only_signer is_majority_sig(id, "remove_trusted"){
    _target_trust_list.remove_trusted(addr);
  }

  function transferOwnership(uint64 id, address newOwner)
    public only_signer is_majority_sig(id, "transferOwnership"){
    _target_trust_list.transferOwnership(newOwner);
  }
}

contract MSATrustListFactory {
  event NewMSATrustList(address addr);

  function createMSATrustList(address _tl, address _multisig)
    public returns(address){
      MSATrustList ac = new MSATrustList(_tl, _multisig);
      emit NewMSATrustList(address(ac));
      return address(ac);
  }
}
