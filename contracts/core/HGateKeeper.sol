pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../ystream/IYieldStream.sol";
import "./HEnv.sol";
import "./HPeriodToken.sol";

contract HDispatcherInterface{
  function getYieldStream(address _token_addr) public view returns (IYieldStream);
}
contract TokenBankInterface{
  function issue(address payable _to, uint _amount) public returns(bool success);
}

contract ClaimHandlerInterface{
  function handle_create_contract(address from, address lop_token_addr) public;
  function handle_claim(address from, address lp_token_addr, uint256 amount) public;
}

contract HGateKeeper is Ownable{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  HDispatcherInterface public dispatcher;
  address public target_token;
  HEnv public env;

  HPeriodToken public period_token;
  ClaimHandlerInterface public claim_handler;
  address public yield_interest_pool;

  uint256 public settled_period;
  uint256 public max_amount;
  struct period_price_info{
    uint256 start_price;
    uint256 end_price;
  }

  mapping (uint256 => uint256) public period_token_amount;
  mapping (uint256 => period_price_info) public period_prices;


  constructor(address _token_addr, address _env, address _dispatcher, address _period_token) public{
    target_token = _token_addr;
    env = HEnv(_env);
    dispatcher = HDispatcherInterface(_dispatcher);
    period_token = HPeriodToken(_period_token);
    settled_period = 0;
  }

  event ChangeClaimHandler(address old, address _new);
  function changeClaimHandler(address handler) public onlyOwner{
    address old = address(claim_handler);
    claim_handler = ClaimHandlerInterface(handler);
    emit ChangeClaimHandler(old, handler);
  }

  event ChangeMaxAmount(uint256 old, uint256 _new);
  function set_max_amount(uint _amount) public onlyOwner{
    uint256 old = max_amount;
    max_amount = _amount;
    emit ChangeMaxAmount(old, max_amount);
  }

  event HorizonBid(address from, uint256 amount, uint256 ratio, address lp_token_addr);
  function bidRatio(uint256 _amount, uint256 _ratio) public returns(address lp_token_addr){
    require(_ratio == 0 || isSupportRatio(_ratio), "not support ratio");
    (address addr, bool created) = period_token.getOrCreateToken(_ratio);

    if(created){
      if(claim_handler != ClaimHandlerInterface(0x0)){
        claim_handler.handle_create_contract(msg.sender, addr);
      }
    }

    if(max_amount > 0){
      require(_amount <= max_amount, "too large amount");
      require(_amount.safeAdd((IERC20(addr).balanceOf(msg.sender)).safeMul(dispatcher.getYieldStream(target_token).getDecimal()).safeDiv(1e18)) <= max_amount, "please use another wallet");
    }


    _check_period();

    ///*
    require(IERC20(target_token).allowance(msg.sender, address(this)) >= _amount, "not enough allowance");
    uint _before = IERC20(target_token).balanceOf(address(this));
    IERC20(target_token).safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = IERC20(target_token).balanceOf(address(this));
    _amount = _after.safeSub(_before); // Additional check for deflationary tokens

    uint256 decimal = dispatcher.getYieldStream(target_token).getDecimal();
    require(decimal <= 1e18, "decimal too large");
    uint256 shares = _amount.safeMul(1e18).safeDiv(decimal);

    uint256 period = HTokenInterface(addr).period_number();
    period_token_amount[period] = period_token_amount[period].safeAdd(_amount);


    HTokenInterface(addr).mint(msg.sender, shares);

    emit HorizonBid(msg.sender, _amount, _ratio, addr);
    return addr;
    //*/
  }

  function bidFloating(uint256 _amount) public returns(address lp_token_addr){
    return bidRatio(_amount, 0);
  }

  event CancelBid(address from, uint256 amount, uint256 fee, address _lp_token_addr);
  function cancelBid(address _lp_token_addr) public{
    bool is_valid = period_token.isPeriodTokenValid(_lp_token_addr);
    require(is_valid, "invalid lp token address");
    uint256 amount = IERC20(_lp_token_addr).balanceOf(msg.sender);
    require(amount > 0, "no bid at this period");

    _check_period();

    uint256 period = HTokenInterface(_lp_token_addr).period_number();
    require(period_token.getCurrentPeriod() < period,
           "period sealed already");

    HTokenInterface(_lp_token_addr).burnFrom(msg.sender, amount);

    uint256 decimal = dispatcher.getYieldStream(target_token).getDecimal();

    uint256 target_amount = amount.safeMul(decimal).safeDiv(1e18);

    period_token_amount[period] = period_token_amount[period].safeSub(target_amount);
    if(env.cancel_fee_ratio() != 0 && env.fee_pool_addr() != address(0x0)){
      uint256 fee = target_amount.safeMul(env.cancel_fee_ratio()).safeDiv(env.ratio_base());
      uint256 recv = target_amount.safeSub(fee);
      IERC20(target_token).safeTransfer(msg.sender, recv);
      IERC20(target_token).safeTransfer(env.fee_pool_addr(), fee);
      emit CancelBid(msg.sender, recv, fee, _lp_token_addr);
    }else{
      IERC20(target_token).safeTransfer(msg.sender, target_amount);
      emit CancelBid(msg.sender, target_amount, 0, _lp_token_addr);
    }

  }

  function changeBid(address _lp_token_addr, uint256 _new_amount, uint256 _new_ratio) public{
    cancelBid(_lp_token_addr);
    bidRatio(_new_amount, _new_ratio);
  }

  event HorizonClaim(address from, address _lp_token_addr, uint256 amount, uint256 fee);
  function claim(address _lp_token_addr, uint256 _amount) public {
    bool is_valid = period_token.isPeriodTokenValid(_lp_token_addr);
    require(is_valid, "invalid lp token address");
    uint256 amount = IERC20(_lp_token_addr).balanceOf(msg.sender);
    require(amount >= _amount, "no enough bid at this period");

    _check_period();
    require(period_token.isPeriodEnd(HTokenInterface(_lp_token_addr).period_number()), "period not end");

    uint total = IERC20(_lp_token_addr).totalSupply();
    uint underly = HTokenInterface(_lp_token_addr).underlying_balance();
    HTokenInterface(_lp_token_addr).burnFrom(msg.sender, _amount);
    uint t = _amount.safeMul(underly).safeDiv(total);
    HTokenInterface(_lp_token_addr).setUnderlyingBalance(underly.safeSub(t));

    if(env.withdraw_fee_ratio() != 0 && env.fee_pool_addr() != address(0x0)){
      uint256 fee = t.safeMul(env.withdraw_fee_ratio()).safeDiv(env.ratio_base());
      uint256 recv = t.safeSub(fee);
      IERC20(target_token).safeTransfer(msg.sender, recv);
      IERC20(target_token).safeTransfer(env.fee_pool_addr(), fee);
      emit HorizonClaim(msg.sender, _lp_token_addr, recv, fee);
    }else{
      IERC20(target_token).safeTransfer(msg.sender, t);
      emit HorizonClaim(msg.sender, _lp_token_addr, t, 0);
    }

    if(claim_handler != ClaimHandlerInterface(0x0)){
      claim_handler.handle_claim(msg.sender, _lp_token_addr, _amount);
    }
  }

  function claimAllAndBidForNext(address _lp_token_addr,  uint256 _ratio, uint256 _next_bid_amount) public{

    uint256 amount = IERC20(_lp_token_addr).balanceOf(msg.sender);
    claim(_lp_token_addr, amount);

    uint256 new_amount = IERC20(target_token).balanceOf(msg.sender);
    if(new_amount > _next_bid_amount){
      new_amount = _next_bid_amount;
    }
    bidRatio(new_amount, _ratio);
  }

  function _check_period() internal{
    period_token.updatePeriodStatus();

    uint256 new_period = period_token.getCurrentPeriod();
    if(period_prices[new_period].start_price == 0){
      period_prices[new_period].start_price = dispatcher.getYieldStream(target_token).getVirtualPrice();
    }
    if(period_token.isPeriodEnd(settled_period + 1)){
      _settle_period(settled_period + 1);
    }
  }

  mapping (uint256 => bool) public support_ratios;
  uint256[] public sratios;

  event SupportRatiosChanged(uint256[] rs);
  function resetSupportRatios(uint256[] memory rs) public onlyOwner{
    for(uint i = 0; i < sratios.length; i++){
      delete support_ratios[sratios[i]];
    }
    delete sratios;
    for(uint i = 0; i < rs.length; i++){
      if(i > 0){
        require(rs[i] > rs[i-1], "should be ascend");
      }
      sratios.push(rs[i]);
      support_ratios[rs[i]] = true;
    }
    emit SupportRatiosChanged(sratios);
  }

  function isSupportRatio(uint256 r) public view returns(bool){
    for(uint i = 0; i < sratios.length; i++){
      if(sratios[i] == r){
        return true;
      }
    }
    return false;
  }

  function updatePeriodStatus() public{
    _check_period();
  }

  function _settle_period(uint256 _period) internal{
    if(period_prices[_period].end_price== 0){
      period_prices[_period].end_price= dispatcher.getYieldStream(target_token).getVirtualPrice();
    }


    uint256 tdecimal = dispatcher.getYieldStream(target_token).getDecimal();
    uint256 left = period_token_amount[_period].safeMul(period_prices[_period].end_price.safeSub(period_prices[_period].start_price));

    uint256 s = 0;
    address fht = period_token.htokenAtPeriodWithRatio(_period, 0);

    for(uint256 i = 0; i < sratios.length; i++){
      uint256 t = period_token.totalAtPeriodWithRatio(_period, sratios[i]).safeMul(tdecimal).safeDiv(1e18);
      uint256 nt = t.safeMul(period_prices[_period].start_price).safeMul(sratios[i]).safeDiv(env.ratio_base());

      address c = period_token.htokenAtPeriodWithRatio(_period, sratios[i]);
      if(c != address(0x0)){
        if(nt > left){
          nt = left;
        }
        left = left.safeSub(nt);
        t = t.safeMul(period_prices[_period].start_price).safeAdd(nt).safeDiv(period_prices[_period].end_price);
        HTokenInterface(c).setUnderlyingBalance(t);
        s = s.safeAdd(t);
      }
    }

    if(fht != address(0x0)){
      left = period_token_amount[_period].safeSub(s);
      HTokenInterface(fht).setUnderlyingBalance(left);
      s = s.safeAdd(left);
    }
    if(s < period_token_amount[_period]){
      s = period_token_amount[_period].safeSub(s);
      require(yield_interest_pool != address(0x0), "invalid yield interest pool");
      IERC20(target_token).safeTransfer(yield_interest_pool, s);
    }

    settled_period = _period;
  }

  event ChangeYieldInterestPool(address old, address _new);
  function changeYieldPool(address _pool) onlyOwner public{
    require(_pool != address(0x0), "invalid pool");
    address old = yield_interest_pool;
    yield_interest_pool = _pool;
    emit ChangeYieldInterestPool(old, _pool);
  }

}

contract HGateKeeperFactory is Ownable{
  event NewGateKeeper(address addr);

  function createGateKeeperForPeriod(address _env_addr, address _dispatcher, address _period_token) public returns(address){
    HEnv e = HEnv(_env_addr);
    HGateKeeper gk = new HGateKeeper(e.token_addr(), _env_addr, _dispatcher, _period_token);
    gk.transferOwnership(msg.sender);
    emit NewGateKeeper(address(gk));
    return address(gk);
  }
}

