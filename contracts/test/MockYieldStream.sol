pragma solidity >=0.4.21 <0.6.0;

import "../ystream/IYieldStream.sol";
import "../erc20/SafeERC20.sol";
import "../utils/TokenClaimer.sol";
import "../utils/SafeMath.sol";

contract MTokenInterface is TransferableToken{
    function issue(address account, uint num) public;
}

contract MockYieldStream is IYieldStream{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  address public token_addr;

  uint256 cur_price;
  constructor(address _addr) public {
    name = "test.mock.yieldstream";
    token_addr = _addr;
    cur_price = 1000000000000000000;
  }

  function target_token() public view returns(address){
    return token_addr;
  }

  function getVirtualPrice() public view returns(uint256){
    return cur_price;
  }

    //we simulate the yield here
  function earn(uint percent) public{
    cur_price = cur_price.safeMul(10000 + percent).safeDiv(10000);
  }

  function getDecimal() public pure returns(uint256){
    return 1e18;
  }
  function getPriceDecimal() public pure returns(uint256){
    return 1e18;
  }
}

contract MockYieldStreamFactory{
  event NewMockYieldStream(address addr);

  function createMockYieldStream(address _token_addr) public returns(address addr){
    MockYieldStream mys = new MockYieldStream(_token_addr);

    emit NewMockYieldStream(address(mys));
    return address(mys);
  }
}
