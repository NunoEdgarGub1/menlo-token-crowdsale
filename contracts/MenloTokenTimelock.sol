pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/SafeERC20.sol';

/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract MenloTokenTimelock {
  using SafeERC20 for ERC20Basic;

  // ERC20 basic token contract being held
  ERC20Basic public token;

  mapping (address => uint) public balance;

  // timestamp when token release is enabled
  uint256 public releaseTime;

  function MenloTokenTimelock(ERC20Basic _token, uint256 _releaseTime) public {
    require(_releaseTime > now);
    token = _token;
    releaseTime = _releaseTime;
  }
  // TODO: callable only by contract
  function deposit(address _beneficiary, uint256 _amount) public {
    balance[_beneficiary] += _amount;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    require(now >= releaseTime);

    uint256 amount = token.balanceOf(this);
    require(amount > 0);
    require(balance[msg.sender] > 0);
    require(amount >= balance[msg.sender]);
    // release each presale participants tokens 
    token.transfer(msg.sender, balance[msg.sender]);
  }
}
