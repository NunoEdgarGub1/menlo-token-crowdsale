"use strict";
var METToken = artifacts.require("MenloToken.sol");
var METVesting = artifacts.require("./helpers/MenloTokenVestingMock.sol");
const BigNumber = require("bignumber.js");
const assertFail = require("./helpers/assertFail");
import { latestTime, duration } from "./helpers/latestTime";

contract("MenloTokenVesting", async function([miner, owner, reserve, notReserve]) {
  let metVestingDeployed;
  let tokenDeployed;
  let startTime;
  let cliffTime;
  let releaseTime;
  let period;
  describe("Reserve", async function() {
    // Reserve:
    //   - 450m MET
    //   - vested until April 18th, 2018
    //   - with 10m MET released every month
    //   - sent to a single address
    beforeEach(async function() {
      cliffTime = 1524009600; // 04/18/2018 @ 12:00am (UTC)
      startTime = cliffTime - duration.months(1);
      releaseTime = startTime + duration.months(45);
      period = duration.months(1);
      tokenDeployed = await METToken.new();

      metVestingDeployed = await METVesting.new(
        tokenDeployed.address,
        startTime,
        cliffTime,
        releaseTime,
        period,
        new BigNumber(450000000).mul(10 ** 18),
        { from: owner }
      );

      await tokenDeployed.transfer(
        metVestingDeployed.address,
        new BigNumber(450000000).mul(10 ** 18)
      );
    });

    it("Owner of the vesting contract can allocate tokens to an address", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          reserve,
          new BigNumber(450000000).mul(10 ** 18)
        );
      });

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          "0x0",
          new BigNumber(450000000).mul(10 ** 18),
          { from: owner }
        );
      });

      await metVestingDeployed.allocate(
        reserve,
        new BigNumber(450000000).mul(10 ** 18),
        { from: owner }
      );
      let allocated = await metVestingDeployed.allocated.call();
      assert.equal(allocated.toNumber(), 450000000 * 10 ** 18);

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          reserve,
          new BigNumber(50000000).mul(10 ** 18)
        );
      });

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notReserve,
          new BigNumber(50000000).mul(10 ** 18),
          { from: owner }
        );
      });

      assert.equal(
        (await metVestingDeployed.allocations(reserve)).toNumber(),
        450000000 * 10 ** 18
      );
      assert.isTrue(await metVestingDeployed.allocationFinished());
    });

    it("Reserve will remove 10 Million MET per month (30 days) starting in April 18th, 2018", async () => {
      await metVestingDeployed.allocate(
        reserve,
        new BigNumber(450000000).mul(10 ** 18),
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(reserve)).toNumber(),
        450000000 * 10 ** 18
      );
      await metVestingDeployed.setBlockTimestamp(
        1524009600 - duration.days(14)
      );
      await assertFail(async () => {
        await metVestingDeployed.collect({ from: reserve });
      });
      await metVestingDeployed.setBlockTimestamp(1524009600);
      await metVestingDeployed.collect({ from: reserve });
      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        10000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(13)
      );
      await metVestingDeployed.collect({ from: reserve });

      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        130000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(24)
      );
      await metVestingDeployed.collect({ from: reserve });

      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        240000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(40)
      );
      await metVestingDeployed.collect({ from: reserve });

      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        400000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(45)
      );
      await metVestingDeployed.collect({ from: reserve });

      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        450000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(60)
      );
      await metVestingDeployed.collect({ from: reserve });

      assert.equal(
        (await tokenDeployed.balanceOf(reserve)).toNumber(),
        450000000 * 10 ** 18
      );
    });

    it("Admin can Claim Token excess of tokens", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());
      await metVestingDeployed.allocate(
        reserve,
        new BigNumber(400000000).mul(10 ** 18),
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(reserve)).toNumber(),
        400000000 * 10 ** 18
      );
      await assertFail(async () => {
        await metVestingDeployed.finishAllocation();
      });
      await metVestingDeployed.finishAllocation({ from: owner });
      assert.isTrue(await metVestingDeployed.allocationFinished());
      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notReserve,
          new BigNumber(50000000).mul(10 ** 18),
          { from: owner }
        );
      });

      await assertFail(async () => {
        await metVestingDeployed.claimTokens(tokenDeployed.address);
      });

      assert.equal((await tokenDeployed.balanceOf(owner)).toNumber(), 0);
      await metVestingDeployed.claimTokens(tokenDeployed.address, {
        from: owner
      });

      assert.equal(
        (await tokenDeployed.balanceOf(owner)).toNumber(),
        50000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(metVestingDeployed.address)).toNumber(),
        400000000 * 10 ** 18
      );
    });
  });
});
