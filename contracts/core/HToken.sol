pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/ERC20Impl.sol";

contract HToken is ERC20Base, Ownable{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  uint256 public ratio_base;

  uint256 public period_number;
  uint256 public ratio; // 0 is for floating

  address public target_token;
  uint256 public underlying_balance;

  constructor(string memory _name, string memory _symbol, uint256 _period, uint256 _ratio)
  ERC20Base(ERC20Base(address(0x0)), 0, _name, 18, _symbol, true) public{
    period_number = _period;
    ratio = _ratio;
    ratio_base = 10000;
  }

  function mint(address addr, uint256 amount) onlyOwner public{
    _generateTokens(addr, amount);
  }
  function burnFrom(address addr, uint256 amount) onlyOwner public{
    _destroyTokens(addr, amount);
  }

  function setTargetToken(address _target) onlyOwner public{
    target_token = _target;
  }

  event HTokenSetUnderlyingBalance(uint256 balance);
  function setUnderlyingBalance(uint256 _balance) onlyOwner public{
    underlying_balance = _balance;
    emit HTokenSetUnderlyingBalance(_balance);
  }

}

contract HTokenFactory{
  event NewHToken(address addr);
  function createFixedRatioToken(address _token_addr, uint256 _period, uint256 _ratio, string memory _postfix) public returns(address){
    string memory name = string(abi.encodePacked("horizon_", ERC20Base(_token_addr).name(), "_", _postfix, "_", uint2str(_ratio), "_", uint2str(_period)));
    string memory symbol = string(abi.encodePacked("h", ERC20Base(_token_addr).symbol(), "_", _postfix, "_", uint2str(_ratio), "w", uint2str(_period)));

    HToken pt = new HToken(name, symbol, _period, _ratio);
    pt.transferOwnership(msg.sender);
    emit NewHToken(address(pt));
    return address(pt);
  }

  function createFloatingToken(address _token_addr, uint256 _period, string memory _postfix) public returns(address){
    string memory name = string(abi.encodePacked("horizon_", ERC20Base(_token_addr).name(), "_", _postfix, "_floating_", uint2str(_period)));
    string memory symbol = string(abi.encodePacked("h", ERC20Base(_token_addr).symbol(), "_", _postfix, "_fw", uint2str(_period)));

    HToken pt = new HToken(name, symbol, _period, 0);
    pt.transferOwnership(msg.sender);
    emit NewHToken(address(pt));
    return address(pt);
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
}
