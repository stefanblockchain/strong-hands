import { expect } from "chai";
import { ethers, network } from "hardhat";

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
        const { strongHand, ownerAccount, otherAccount, aaveTokenWhale, questAccount, lockTime, pool, weth, weithAToken } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");
        const depositDaiAmount = (await weithAToken.balanceOf(aaveTokenWhale.address)).sub((await weithAToken.balanceOf(aaveTokenWhale.address)).div(ethers.utils.parseEther("3")));
        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await weithAToken.connect(aaveTokenWhale).transfer(strongHand.address, depositDaiAmount);
        const prevBalance = await ownerAccount.getBalance();
        const txt = await strongHand.connect(ownerAccount).takeInterest();
        const txtPrice = await calculateTransactionPrice(txt);
        const currBalance = await ownerAccount.getBalance();
        expect(currBalance).to.be.equal(prevBalance.sub(txtPrice).add(depositDaiAmount));
    });

    it("Should emit event on interest take", async function () {
        const { strongHand, ownerAccount, otherAccount, aaveTokenWhale, questAccount, lockTime, pool, weth, weithAToken } = await deployStrongHandFixture();
        const interestAmount = await weithAToken.balanceOf(aaveTokenWhale.address);
        console.log(interestAmount);
        await weithAToken.connect(aaveTokenWhale).transfer(strongHand.address, interestAmount);
        await expect(strongHand.connect(ownerAccount).takeInterest()).to.emit(strongHand, "OwnerInterestEvent").withArgs(ownerAccount.address, interestAmount);

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

    it("Should return unchange amount", async function () {
        const { strongHand, otherAccount, lockTime } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");

        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await increaseTime(lockTime);
        const reedemTxt = await (await strongHand.connect(otherAccount).reedem()).wait();
        const args = reedemTxt.events ? reedemTxt.events[reedemTxt.events?.length - 1].args : reedemTxt.events;
        expect(args![1]).to.be.equal(depositAmount);
    });

    it("Should increase balance", async function () {
        let reedemTxt, args, exitAmount, prevBalance, gasPaid, currBalance;

        const { strongHand, otherAccount, questAccount, lockTime } = await deployStrongHandFixture();
        const depositAmount = ethers.utils.parseEther("1");

        await strongHand.connect(otherAccount).deposit({ value: depositAmount });
        await strongHand.connect(questAccount).deposit({ value: depositAmount });

        reedemTxt = await (await (strongHand.connect(otherAccount).reedem())).wait();
        args = reedemTxt.events ? reedemTxt.events[reedemTxt.events?.length - 1].args : reedemTxt.events;
        exitAmount = args![1];
        await increaseTime(lockTime);

        prevBalance = await questAccount.getBalance();
        reedemTxt = await (await strongHand.connect(questAccount).reedem()).wait();
        args = reedemTxt.events ? reedemTxt.events[reedemTxt.events?.length - 1].args : reedemTxt.events;
        const { gasUsed, effectiveGasPrice } = reedemTxt;
        gasPaid = gasUsed.mul(effectiveGasPrice);
        currBalance = await questAccount.getBalance();

        expect(args![1]).to.be.greaterThan(depositAmount);
        console.log("Amount", args![1].sub(depositAmount));
        expect(args![1]).to.be.equal(depositAmount.add(depositAmount).sub(exitAmount));
        expect(currBalance).to.be.equal(prevBalance.sub(gasPaid).add(args![1]));
    });
});


async function deployStrongHandFixture() {
    let strongHand, feeStrategyV1, networkConf: any, lockTime, ownerAccount, otherAccount, questAccount, poolAddressesProvider, pool, weth, aaveTokenWhale, weithAToken;

    [ownerAccount, otherAccount, questAccount] = await ethers.getSigners();

    lockTime = 24 * 60 * 60;
    networkConf = helperConfig.networkConfig.find(el => el.name === network.name);

    feeStrategyV1 = await (await ethers.getContractFactory("FeeStrategyV1")).deploy();

    strongHand = await ethers.getContractFactory("StrongHand");
    strongHand = await strongHand.deploy(lockTime, networkConf.poolAddressesProvider, networkConf.weithAToken, feeStrategyV1.address, networkConf.wethGateway, networkConf.wethAddress);

    poolAddressesProvider = await ethers.getContractAt("IPoolAddressesProvider", networkConf.poolAddressesProvider);
    pool = await ethers.getContractAt("IPool", (await poolAddressesProvider.getPool()));

    weth = await ethers.getContractAt("IWETH", networkConf.wethAddress);
    weithAToken = await ethers.getContractAt("IWETH", networkConf.weithAToken);
    aaveTokenWhale = await ethers.getImpersonatedSigner(networkConf.weithATokenWhale);

    return { strongHand, feeStrategyV1, ownerAccount, otherAccount, questAccount, lockTime, poolAddressesProvider, pool, weth, aaveTokenWhale, weithAToken };
}

async function calculateTransactionPrice(transaction: any) {
    const { gasUsed, effectiveGasPrice } = await transaction.wait();
    return gasUsed.mul(effectiveGasPrice);

}

async function increaseTime(timeInSeconds: number) {
    await ethers.provider.send('evm_increaseTime', [timeInSeconds]);
    await network.provider.send("evm_mine");
}
