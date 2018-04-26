pragma solidity ^0.4.23;

import 'zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol';

/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract MenloTokenTimelock {
  using SafeERC20 for ERC20Basic;

  // ERC20 basic token contract being held
  ERC20Basic public token;

  // MENLO-NOTE!
  mapping (address => uint) public balance;

  // timestamp when token release is enabled
  uint256 public releaseTime;

  // MENLO-NOTE!
  address public presale;

  modifier onlyPresale() {
    require(msg.sender == presale);
    _;
  }

  constructor(ERC20Basic _token, address _presale, uint256 _releaseTime) public {
    require(_releaseTime > now);
    token = _token;
    presale = _presale;
    releaseTime = _releaseTime;
  }

  // MENLO-NOTE!
  function deposit(address _beneficiary, uint256 _amount) public onlyPresale {
    balance[_beneficiary] += _amount;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    require(now >= releaseTime);

    uint256 _amount = token.balanceOf(this);
    require(_amount > 0);
    // MENLO-NOTE!
    require(balance[msg.sender] > 0);
    require(_amount >= balance[msg.sender]);
    token.transfer(msg.sender, balance[msg.sender]);
  }
}
