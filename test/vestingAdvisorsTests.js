"use strict";
var METToken = artifacts.require("MenloToken.sol");
var METVesting = artifacts.require("./helpers/MenloTokenVestingMock.sol");
const BigNumber = require("bignumber.js");
const assertFail = require("./helpers/assertFail");
import { latestTime, duration } from "./helpers/latestTime";

contract("MenloTokenVesting", async function([miner, owner, advisor1, advisor2, notAdvisor]) {
  let metVestingDeployed;
  let tokenDeployed;
  let startTime;
  let cliffTime;
  let releaseTime;
  let period;

  describe("Advisors", async function() {
    // Advisors:
    //   - 25m MET
    //   - vested until August 23rd, 2018
    //   - we specify numbers/addresses
    beforeEach(async function() {
      startTime = latestTime() + duration.days(1);
      cliffTime = 1534982400; // 08/23/2018 @ 12:00am (UTC)
      releaseTime = 1534982400; // 08/23/2018 @ 12:00am (UTC)
      period = 1; // No period
      tokenDeployed = await METToken.new();

      metVestingDeployed = await METVesting.new(
        tokenDeployed.address,
        startTime,
        cliffTime,
        releaseTime,
        period,
        new BigNumber(25000000).mul(10 ** 18),
        { from: owner }
      );

      await tokenDeployed.transfer(
        metVestingDeployed.address,
        new BigNumber(25000000).mul(10 ** 18)
      );
    });

    it("Owner of the vesting contract can allocate tokens to multiple addresses", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());
      await metVestingDeployed.allocate(
        advisor1,
        new BigNumber(10000000).mul(10 ** 18),
        { from: owner }
      );
      let allocated = await metVestingDeployed.allocated.call();
      assert.equal(allocated.toNumber(), 10000000 * 10 ** 18);

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          advisor2,
          new BigNumber(15000000).mul(10 ** 18)
        );
      });

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          "0x0",
          new BigNumber(15000000).mul(10 ** 18),
          { from: owner }
        );
      });

      await metVestingDeployed.allocate(
        advisor2,
        new BigNumber(15000000).mul(10 ** 18),
        { from: owner }
      );
      allocated = await metVestingDeployed.allocated.call();
      assert.equal(allocated.toNumber(), 25000000 * 10 ** 18);

      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notAdvisor,
          new BigNumber(15000000).mul(10 ** 18),
          { from: owner }
        );
      });

      assert.equal(
        (await metVestingDeployed.allocations(advisor1)).toNumber(),
        10000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(advisor2)).toNumber(),
        15000000 * 10 ** 18
      );
      assert.isTrue(await metVestingDeployed.allocationFinished());
    });

    it("Advisors will remove the entirety of their tokens by August 23rd, 2018", async () => {
      await metVestingDeployed.allocateArray(
        [advisor1, advisor2],
        [
          new BigNumber(10000000).mul(10 ** 18),
          new BigNumber(15000000).mul(10 ** 18)
        ],
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(advisor1)).toNumber(),
        10000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(advisor2)).toNumber(),
        15000000 * 10 ** 18
      );
      await metVestingDeployed.setBlockTimestamp(
        1534983400 - duration.days(1)
      );
      await assertFail(async () => {
        await metVestingDeployed.collect({ from: advisor1 });
      });
      await metVestingDeployed.setBlockTimestamp(1534982400);

      await metVestingDeployed.collect({ from: advisor1 });
      await metVestingDeployed.collect({ from: advisor2 });

      assert.equal(
        (await tokenDeployed.balanceOf(advisor1)).toNumber(),
        10000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(advisor2)).toNumber(),
        15000000 * 10 ** 18
      );

      await metVestingDeployed.setBlockTimestamp(
        1534983400 + duration.months(6)
      );
      await metVestingDeployed.collect({ from: advisor1 });
      await metVestingDeployed.collect({ from: advisor2 });

      assert.equal(
        (await tokenDeployed.balanceOf(advisor1)).toNumber(),
        10000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(advisor2)).toNumber(),
        15000000 * 10 ** 18
      );
    });

    it("Admin can Claim Token excess of tokens", async () => {
      assert.isFalse(await metVestingDeployed.allocationFinished());

      await metVestingDeployed.allocateArray(
        [advisor1, advisor2],
        [
          new BigNumber(10000000).mul(10 ** 18),
          new BigNumber(10000000).mul(10 ** 18)
        ],
        { from: owner }
      );
      assert.equal(
        (await metVestingDeployed.allocations(advisor1)).toNumber(),
        10000000 * 10 ** 18
      );
      assert.equal(
        (await metVestingDeployed.allocations(advisor2)).toNumber(),
        10000000 * 10 ** 18
      );
      await assertFail(async () => {
        await metVestingDeployed.finishAllocation();
      });
      await metVestingDeployed.finishAllocation({ from: owner });
      assert.isTrue(await metVestingDeployed.allocationFinished());
      await assertFail(async () => {
        await metVestingDeployed.allocate(
          notAdvisor,
          new BigNumber(5000000).mul(10 ** 18),
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
        5000000 * 10 ** 18
      );

      assert.equal(
        (await tokenDeployed.balanceOf(metVestingDeployed.address)).toNumber(),
        20000000 * 10 ** 18
      );
    });
  });
});
