import { expect } from "chai";
import { ethers } from "hardhat";

describe("Calculate fee", function () {
    it("Should return  50% fee when at same block", async function () {
        const { feeStrategyV1, balance, lockTime } = await deployStrongHandFixture();
        const curTamp = await getBlockTime();
        const fee = ethers.utils.parseEther("0.5");
        expect(await feeStrategyV1.calculateAccountFee(curTamp + lockTime, lockTime, balance)).to.be.equal(fee);
    });

    it("Should return  0% fee if reedem time is before this block", async function () {
        const { feeStrategyV1, balance, lockTime } = await deployStrongHandFixture();
        const curTamp = await getBlockTime();
        const fee = ethers.utils.parseEther("0");
        expect(await feeStrategyV1.calculateAccountFee(curTamp - 1, lockTime, balance)).to.be.equal(fee);
    });

    it("Should return  25% fee", async function () {
        const { feeStrategyV1, balance, lockTime } = await deployStrongHandFixture();
        const curTamp = await getBlockTime();
        const fee = ethers.utils.parseEther("0.25");
        expect(await feeStrategyV1.calculateAccountFee(curTamp + lockTime / 2, lockTime, balance)).to.be.equal(fee);
    });

    it("Should return 0% fee", async function () {
        const { feeStrategyV1, balance, lockTime } = await deployStrongHandFixture();
        const curTamp = await getBlockTime();
        const fee = ethers.utils.parseEther("0");
        expect(await feeStrategyV1.calculateAccountFee(curTamp - lockTime, lockTime, balance)).to.be.equal(fee);
    });
});

async function deployStrongHandFixture() {
    let feeStrategyV1, lockTime, balance;
    feeStrategyV1 = await (await ethers.getContractFactory("FeeStrategyV1")).deploy();
    balance = ethers.utils.parseEther("1");
    lockTime = 24 * 60 * 60;

    return { feeStrategyV1, lockTime, balance };
}

async function getBlockTime() {
    const lastBLockNumber = await ethers.provider.getBlockNumber();
    const lastBlock = await ethers.provider.getBlock(lastBLockNumber);
    return lastBlock.timestamp;
}