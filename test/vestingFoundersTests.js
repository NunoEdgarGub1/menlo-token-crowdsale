"use strict";
var METToken = artifacts.require("MenloToken.sol");
var METVesting = artifacts.require("./helpers/MenloTokenVestingMock.sol");
const BigNumber = require("bignumber.js");
const assertFail = require("./helpers/assertFail");
import { latestTime, duration } from "./helpers/latestTime";

contract("MenloTokenVesting", async function(
  [miner, owner, founder1, founder2, notFounder]
) {
  let metVestingDeployed;
  let tokenDeployed;
  let startTime;
  let cliffTime;
  let releaseTime;
  let period;
  describe("Founders", async function() {
    // Founders:
    //   - 150m MET
    //   - 1/4th vested until 1 year cliff
    //   - with 1/48th vest every month thereafter
    //   - allocated to multiple addresses that we specify.
    beforeEach(async function() {
      startTime = latestTime() + duration.days(1);
      cliffTime = startTime + duration.months(12);
      releaseTime = startTime + duration.months(48);
      period = duration.months(1);
      tokenDeployed = await METToken.new();

      metVestingDeployed = await METVesting.new(
        tokenDeployed.address,
        startTime,
        cliffTime,
        releaseTime,
        period,
        new BigNumber(150000000).mul(10 ** 18),
        { from: owner }
      );

      await tokenDeployed.transfer(
        metVestingDeployed.address,
        new BigNumber(150000000).mul(10 ** 18)
      );
    });

    it("Owner of the vesting contract can allocate tokens to multiple addresses", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());
      await metVestingDeployed.allocate(
        founder1,
        new BigNumber(100000000).mul(10 ** 18),
        { from: owner }
      );
      let allocated = await metVestingDeployed.allocated.call();
      assert.equal(allocated.toNumber(), 100000000 * 10 ** 18);

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          founder2,
          new BigNumber(50000000).mul(10 ** 18)
        );
      });

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          "0x0",
          new BigNumber(50000000).mul(10 ** 18),
          { from: owner }
        );
      });

      await metVestingDeployed.allocate(
        founder2,
        new BigNumber(50000000).mul(10 ** 18),
        { from: owner }
      );
      allocated = await metVestingDeployed.allocated.call();
      assert.equal(allocated.toNumber(), 150000000 * 10 ** 18);

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notFounder,
          new BigNumber(50000000).mul(10 ** 18),
          { from: owner }
        );
      });

      assert.equal(
        (await metVestingDeployed.allocations(founder1)).toNumber(),
        100000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(founder2)).toNumber(),
        50000000 * 10 ** 18
      );
      assert.isTrue(await metVestingDeployed.allocationFinished());
    });

    it("Founders will remove 1/48th per month (30 days) only after the first year has passed (360 days)", async () => {
      await metVestingDeployed.allocateArray(
        [founder1, founder2],
        [
          new BigNumber(102000000).mul(10 ** 18),
          new BigNumber(48000000).mul(10 ** 18)
        ],
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(founder1)).toNumber(),
        102000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(founder2)).toNumber(),
        48000000 * 10 ** 18
      );
      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(6)
      );
      await assertFail(async () => {
        await metVestingDeployed.collect({ from: founder1 });
      });
      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(12)
      );
      await metVestingDeployed.collect({ from: founder1 });
      assert.equal(
        (await tokenDeployed.balanceOf(founder1)).toNumber(),
        25500000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(13)
      );
      await metVestingDeployed.collect({ from: founder2 });

      assert.equal(
        (await tokenDeployed.balanceOf(founder2)).toNumber(),
        13000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(24)
      );
      await metVestingDeployed.collect({ from: founder1 });
      await metVestingDeployed.collect({ from: founder2 });

      assert.equal(
        (await tokenDeployed.balanceOf(founder1)).toNumber(),
        51000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(founder2)).toNumber(),
        24000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(40)
      );
      await metVestingDeployed.collect({ from: founder2 });

      assert.equal(
        (await tokenDeployed.balanceOf(founder2)).toNumber(),
        40000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(48)
      );
      await metVestingDeployed.collect({ from: founder1 });
      await metVestingDeployed.collect({ from: founder2 });

      assert.equal(
        (await tokenDeployed.balanceOf(founder1)).toNumber(),
        102000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(founder2)).toNumber(),
        48000000 * 10 ** 18
      );
      await metVestingDeployed.setBlockTimestamp(
        startTime + duration.months(60)
      );
      await metVestingDeployed.collect({ from: founder1 });
      await metVestingDeployed.collect({ from: founder2 });

      assert.equal(
        (await tokenDeployed.balanceOf(founder1)).toNumber(),
        102000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(founder2)).toNumber(),
        48000000 * 10 ** 18
      );
    });

    it("Admin can Claim Token excess of tokens", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());
      await metVestingDeployed.allocateArray(
        [founder1, founder2],
        [
          new BigNumber(100000000).mul(10 ** 18),
          new BigNumber(40000000).mul(10 ** 18)
        ],
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(founder1)).toNumber(),
        100000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(founder2)).toNumber(),
        40000000 * 10 ** 18
      );
      await assertFail(async () => {
        await metVestingDeployed.finishAllocation();
      });
      await metVestingDeployed.finishAllocation({ from: owner });
      assert.isTrue(await metVestingDeployed.allocationFinished());
      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notFounder,
          new BigNumber(10000000).mul(10 ** 18),
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
        10000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(metVestingDeployed.address)).toNumber(),
        140000000 * 10 ** 18
      );
    });
  });
});
