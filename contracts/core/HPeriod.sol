pragma solidity >=0.4.21 <0.6.0;
import "../utils/SafeMath.sol";

contract HPeriod{
  using SafeMath for uint;

  uint256 period_start_block;
  uint256 period_block_num;
  uint256 period_gap_block;

  struct period_info{
    uint256 period;
    uint256 start_block;
    uint256 end_block;    // [start_block, end_block)
  }

  mapping (uint256 => period_info) all_periods;
  uint256 current_period;

  bool is_gapping;

  constructor(uint256 _start_block, uint256 _period_block_num, uint256 _gap_block_num) public{
    period_start_block = _start_block;
    period_block_num = _period_block_num;

    period_gap_block = _gap_block_num;
    current_period = 0;
    is_gapping = true;
  }

  function _end_current_and_start_new_period() internal returns(bool){
    require(block.number >= period_start_block, "1st period not start yet");

    if(is_gapping){
      if(current_period == 0 || block.number.safeSub(all_periods[current_period].end_block) >= period_gap_block){
        current_period = current_period + 1;
        all_periods[current_period].period = current_period;
        all_periods[current_period].start_block = block.number;
        is_gapping = false;
        return true;
      }
    }else{
      if(block.number.safeSub(all_periods[current_period].start_block) >= period_block_num){
        all_periods[current_period].end_block = block.number;
        is_gapping = true;
      }
    }
    return false;
  }


  event HPeriodChanged(uint256 old, uint256 new_period);
  function _change_period(uint256 _period) internal{
    uint256 old = period_block_num;
    period_block_num = _period;
    emit HPeriodChanged(old, period_block_num);
  }

  function getCurrentPeriodStartBlock() public view returns(uint256){
    (, uint256 s, ) = getPeriodInfo(current_period);
    return s;
  }

  function getPeriodInfo(uint256 period) public view returns(uint256 p, uint256 s, uint256 e){
    p = all_periods[period].period;
    s = all_periods[period].start_block;
    e = all_periods[period].end_block;
  }

  function getParamPeriodStartBlock() public view returns(uint256){
    return period_start_block;
  }

  function getParamPeriodBlockNum() public view returns(uint256){
    return period_block_num;
  }

  function getParamPeriodGapNum() public view returns(uint256){
    return period_gap_block;
  }

  function getCurrentPeriod() public view returns(uint256){
    return current_period;
  }

  function isPeriodEnd(uint256 _period) public view returns(bool){
    return all_periods[_period].end_block != 0;
  }

  function isPeriodStart(uint256 _period) public view returns(bool){
    return all_periods[_period].start_block != 0;
  }

}
