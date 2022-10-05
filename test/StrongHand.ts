import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, network, deployments } from "hardhat";

import helperConfig from "../helper-hardhat-config";

describe("OwnerShip", function () {
    it("Should set the owner correctly", async function () {
        const { strongHand, ownerAccount } = await deployStrongHandFixture();
        expect(await strongHand.owner()).to.equal(ownerAccount.address);
    });
})
    ;
describe("Deposit", function () {
    it("Should allow to deposit ether", async function () {
        const { strongHand, ownerAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("0.1");
        const previusBalance = await ownerAccount.getBalance();

        const txt = await strongHand.connect(ownerAccount).deposit({ value: depositAmount });
        const tranCost = await calculateTransactionPrice(txt);
        expect(await ownerAccount.getBalance()).to.equal(previusBalance.sub(depositAmount).sub(tranCost));
    });

    it("Should fail to deposit 0 ether", async function () {
        const { strongHand, ownerAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("0");
        await expect(strongHand.connect(ownerAccount).deposit({ value: depositAmount })).to.be.revertedWithCustomError(strongHand, 'ValueSentIsZeroError');
    });

    it("Should reduce balance in half", async function () {
        const { strongHand, otherAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");
        const exitAmount = ethers.utils.parseEther("0.5");
        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        expect(await strongHand.calculateAccountFee(otherAccount.address)).to.be.equal(exitAmount);
    });

    it("Shouldn't reduce balance", async function () {
        const { strongHand, otherAccount, lockTime } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");
        const feeAmount = ethers.utils.parseEther("0");
        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await increaseTime(lockTime);
        expect(await strongHand.calculateAccountFee(otherAccount.address)).to.be.equal(feeAmount);
    });
});

describe("Interest", function () {
    it("Should fail for none owner user", async function () {
        const { strongHand, otherAccount } = await deployStrongHandFixture();
        await expect(strongHand.connect(otherAccount).takeInterest()).to.be.revertedWith("Ownable: caller is not the owner")
    });

    it("Should fail for owner if not interest is generated", async function () {
        const { strongHand, ownerAccount } = await deployStrongHandFixture();
        await expect(strongHand.connect(ownerAccount).takeInterest()).to.be.revertedWithCustomError(strongHand, "NoInterestToReedemError");
    });

    it("Should allow onwer to take interest", async function () {

    });
});

describe("Reedem", function () {
    it("Should update reedem time for user", async function () {
        const { strongHand, otherAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");
        const transation = await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        const prevReedemTime = (await strongHand.getUserDeposit(otherAccount.address)).reedemTime;
        await transation.wait();
        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        const currentReedmTime = (await strongHand.getUserDeposit(otherAccount.address)).reedemTime;

        expect(currentReedmTime).to.be.greaterThan(prevReedemTime);
    });

    it("Should be able to reedem", async function () {
        const { strongHand, otherAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");
        await strongHand.connect(otherAccount).deposit({ value: depositAmount });

        const prevBalance = await otherAccount.getBalance();
        const reedemTxt = await (await strongHand.connect(otherAccount).reedem()).wait();
        const args = reedemTxt.events ? reedemTxt.events[reedemTxt.events?.length - 1].args : reedemTxt.events;
        const { gasUsed, effectiveGasPrice } = reedemTxt;
        const gasPaid = gasUsed.mul(effectiveGasPrice);
        const currBalance = await otherAccount.getBalance();
        expect(currBalance).to.be.equal(prevBalance.sub(gasPaid).add(args![1]));
        expect(otherAccount.address).to.be.equal(args![0]);
    });

    it("Should emit event when reedeming", async function () {
        const { strongHand, otherAccount } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");

        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await expect(strongHand.connect(otherAccount).reedem()).to.emit(strongHand, "ReedemEvent");

    });

    it("Should return 1 ether amount", async function () {
        const { strongHand, otherAccount, lockTime } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");

        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await increaseTime(lockTime);
        const reedemTxt = await (await strongHand.connect(otherAccount).reedem()).wait();
        const args = reedemTxt.events ? reedemTxt.events[reedemTxt.events?.length - 1].args : reedemTxt.events;
        expect(args![1]).to.be.equal(depositAmount);
    });
});


async function deployStrongHandFixture() {
    let strongHand, feeStrategyV1, networkConf: any, lockTime, ownerAccount, otherAccount, questAccount;

    [ownerAccount, otherAccount, questAccount] = await ethers.getSigners();

    lockTime = 24 * 60 * 60;
    networkConf = helperConfig.networkConfig.find(el => el.name === network.name);
    feeStrategyV1 = await (await ethers.getContractFactory("FeeStrategyV1")).deploy();

    strongHand = await ethers.getContractFactory("StrongHand");
    strongHand = await strongHand.deploy(lockTime, networkConf.poolAddressesProvider, networkConf.weithAToken, feeStrategyV1.address, networkConf.wethGateway, networkConf.wethAddress);
    return { strongHand, feeStrategyV1, ownerAccount, otherAccount, questAccount, lockTime };
}

async function calculateTransactionPrice(transaction: any) {
    const { gasUsed, effectiveGasPrice } = await transaction.wait();
    return gasUsed.mul(effectiveGasPrice);

}

async function increaseTime(timeInSeconds: number) {
    await ethers.provider.send('evm_increaseTime', [timeInSeconds]);
    await network.provider.send("evm_mine");
}
