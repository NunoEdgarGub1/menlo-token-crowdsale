pragma solidity ^0.4.18;

import '../../contracts/MenloTokenVesting.sol';

contract MenloTokenVestingMock is MenloTokenVesting {
  uint256 public timeStamp;

  function setBlockTimestamp(uint256 _timeStamp) public {
    timeStamp = _timeStamp;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    return timeStamp;
  }

  function MenloTokenVestingMock(
      address _token,
      uint256 _startTime,
      uint256 _cliffTime,
      uint256 _releaseTime,
      uint256 _period,
      uint256 _totalTokens
  ) MenloTokenVesting(
      _token,
      _startTime,
      _cliffTime,
      _releaseTime,
      _period,
      _totalTokens
  ) {
    timeStamp = now;
  }
}
