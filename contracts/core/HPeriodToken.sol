pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../erc20/SafeERC20.sol";

import "./HPeriod.sol";

contract HTokenFactoryInterface{
  function createFixedRatioToken(address _token_addr, uint256 _period, uint256 _ratio, string memory _postfix) public returns(address);
  function createFloatingToken(address _token_addr, uint256 _period, string memory _postfix) public returns(address);
}

contract HTokenInterface{
  function mint(address addr, uint256 amount)public;
  function burnFrom(address addr, uint256 amount) public;
  uint256 public period_number;
  uint256 public ratio; // 0 is for floating
  uint256 public underlying_balance;
  function setUnderlyingBalance(uint256 _balance) public;
  function setTargetToken(address _target) public;
}

contract HPeriodToken is HPeriod, Ownable{

  struct period_token_info{
    address[] period_tokens;

    mapping(bytes32 => address) hash_to_tokens;
  }

  mapping (uint256 => period_token_info) all_period_tokens;

  HTokenFactoryInterface public token_factory;
  address public target_token;


  constructor(address _target_token, uint256 _start_block, uint256 _period, uint256 _gap, address _factory)
    HPeriod(_start_block, _period, _gap) public{
    target_token = _target_token;
    token_factory = HTokenFactoryInterface(_factory);
  }

  function uint2str(uint256 i) internal pure returns (string memory c) {
    if (i == 0) return "0";
    uint256 j = i;
    uint256 length;
    while (j != 0){
        length++;
        j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length - 1;
    while (i != 0){
      bstr[k--] = byte(48 + uint8(i % 10));
      i /= 10;
    }
    c = string(bstr);
  }

  function getOrCreateToken(uint ratio) public onlyOwner returns(address, bool){

    _end_current_and_start_new_period();

    uint256 p = getCurrentPeriod();
    bytes32 h = keccak256(abi.encodePacked(target_token, getParamPeriodBlockNum(), ratio, p + 1));
    address c = address(0x0);

    period_token_info storage pi = all_period_tokens[p + 1];

    bool s  = false;
    if(pi.hash_to_tokens[h] == address(0x0)){
      if(ratio == 0){
        c = token_factory.createFloatingToken(target_token, p + 1, uint2str(getParamPeriodBlockNum()));
      }
      else{
        c = token_factory.createFixedRatioToken(target_token, p + 1, ratio, uint2str(getParamPeriodBlockNum()));
      }
      HTokenInterface(c).setTargetToken(target_token);
      Ownable ow = Ownable(c);
      ow.transferOwnership(owner());
      pi.period_tokens.push(c);
      pi.hash_to_tokens[h] = c;
      s = true;
    }
    c = pi.hash_to_tokens[h];

    return(c, s);
  }

  function updatePeriodStatus() public onlyOwner returns(bool){
    return _end_current_and_start_new_period();
  }

  function isPeriodTokenValid(address _token_addr) public view returns(bool){
    HTokenInterface hti = HTokenInterface(_token_addr);
    bytes32 h = keccak256(abi.encodePacked(target_token, getParamPeriodBlockNum(), hti.ratio(), hti.period_number()));
    period_token_info storage pi = all_period_tokens[hti.period_number()];
    if(pi.hash_to_tokens[h] == _token_addr){
      return true;
    }
    return false;
  }

  function totalAtPeriodWithRatio(uint256 _period, uint256 _ratio) public view returns(uint256) {
    bytes32 h = keccak256(abi.encodePacked(target_token, getParamPeriodBlockNum(), _ratio, _period));
    period_token_info storage pi = all_period_tokens[_period];
    address c = pi.hash_to_tokens[h];
    if(c == address(0x0)) return 0;

    IERC20 e = IERC20(c);
    return e.totalSupply();
  }

  function htokenAtPeriodWithRatio(uint256 _period, uint256 _ratio) public view returns(address){
    bytes32 h = keccak256(abi.encodePacked(target_token, getParamPeriodBlockNum(), _ratio, _period));
    period_token_info storage pi = all_period_tokens[_period];
    address c = pi.hash_to_tokens[h];
    return c;
  }
}

contract HPeriodTokenFactory{

  event NewPeriodToken(address addr);
  function createPeriodToken(address _target_token, uint256 _start_block, uint256 _period, uint256 _gap, address _token_factory) public returns(address){
    HPeriodToken pt = new HPeriodToken(_target_token, _start_block, _period, _gap, _token_factory);

    pt.transferOwnership(msg.sender);
    emit NewPeriodToken(address(pt));
    return address(pt);
  }

}


