import { expect } from "chai";
import { Contracts, Env, makeSuite, Snapshots } from "./setup";
import { BigNumber, constants } from "ethers";
import { impersonateAccount, setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { makeBN18 } from "./utils";
import { ethers } from "hardhat";

makeSuite("BendCoinPool", (contracts: Contracts, env: Env, snapshots: Snapshots) => {
  let bot: SignerWithAddress;
  let lastRevert: string;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let stakeManagerSigner: SignerWithAddress;

  before(async () => {
    await impersonateAccount(contracts.bendStakeManager.address);
    await setBalance(contracts.bendStakeManager.address, makeBN18(1));
    bot = env.admin;
    alice = env.accounts[1];
    bob = env.accounts[2];

    await impersonateAccount(contracts.bendStakeManager.address);
    stakeManagerSigner = await ethers.getSigner(contracts.bendStakeManager.address);
    await setBalance(stakeManagerSigner.address, makeBN18(100000));

    await contracts.wrapApeCoin.connect(alice).deposit({ value: makeBN18(1000000) });
    await contracts.wrapApeCoin.connect(alice).approve(contracts.bendCoinPool.address, constants.MaxUint256);

    await contracts.wrapApeCoin.connect(bob).deposit({ value: makeBN18(1000000) });
    await contracts.wrapApeCoin.connect(bob).approve(contracts.bendCoinPool.address, constants.MaxUint256);

    await contracts.bendStakeManager.updateBotAdmin(bot.address);
    lastRevert = "init";
    await snapshots.capture(lastRevert);
  });

  afterEach(async () => {
    if (lastRevert) {
      await snapshots.revert(lastRevert);
    }
  });
  const expectPendingAmountChanged = async (blockTag: number, delta: BigNumber) => {
    const now = await contracts.bendCoinPool.pendingApeCoin({ blockTag });
    const pre = await contracts.bendCoinPool.pendingApeCoin({ blockTag: blockTag - 1 });
    expect(now.sub(pre)).eq(delta);
  };

  it("deposit: preparing the first deposit", async () => {
    await contracts.wrapApeCoin.connect(env.feeRecipient).approve(contracts.bendCoinPool.address, constants.MaxUint256);
    await contracts.bendCoinPool.connect(env.feeRecipient).depositSelf(makeBN18(1));
    expect(await contracts.bendCoinPool.totalSupply()).gt(0);

    lastRevert = "init";
    await snapshots.capture(lastRevert);
  });

  it("deposit: revert when paused", async () => {
    let depositAmount = makeBN18(10000);

    await contracts.bendCoinPool.setPause(true);
    await expect(contracts.bendCoinPool.connect(bob).depositSelf(depositAmount)).revertedWith("Pausable: paused");
    await contracts.bendCoinPool.setPause(false);
  });

  it("deposit", async () => {
    let depositAmount = makeBN18(10000);
    let tx = contracts.bendCoinPool.connect(alice).depositSelf(depositAmount);
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [alice.address, contracts.bendCoinPool.address],
      [constants.Zero.sub(depositAmount), depositAmount]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, depositAmount);

    depositAmount = makeBN18(100);
    tx = contracts.bendCoinPool.connect(bob).mintSelf(await contracts.bendCoinPool.previewMint(depositAmount));
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [bob.address, contracts.bendCoinPool.address],
      [constants.Zero.sub(depositAmount), depositAmount]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, depositAmount);

    lastRevert = "deposit";
    await snapshots.capture(lastRevert);
  });

  it("getVotes", async () => {
    const assetsAmount = await contracts.bendCoinPool.assetBalanceOf(bob.address);
    const votesAmount = await contracts.stakedVoting.getVotes(bob.address);
    expect(assetsAmount).eq(votesAmount);
  });

  it("withdraw: revert when paused", async () => {
    const withdrawAmount = await contracts.bendCoinPool.assetBalanceOf(bob.address);
    await contracts.bendCoinPool.setPause(true);
    await expect(contracts.bendCoinPool.connect(bob).withdrawSelf(withdrawAmount)).revertedWith("Pausable: paused");
    await contracts.bendCoinPool.setPause(false);
  });

  it("redeem: revert when paused", async () => {
    const withdrawAmount = await contracts.bendCoinPool.assetBalanceOf(bob.address);
    await contracts.bendCoinPool.setPause(true);
    await expect(contracts.bendCoinPool.connect(bob).redeemSelf(withdrawAmount)).revertedWith("Pausable: paused");
    await contracts.bendCoinPool.setPause(false);
  });

  it("withdraw: from pending ape coin", async () => {
    const withdrawAmount = await contracts.bendCoinPool.assetBalanceOf(bob.address);
    const tx = contracts.bendCoinPool.connect(bob).withdrawSelf(withdrawAmount);
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [bob.address, contracts.bendCoinPool.address],
      [withdrawAmount, constants.Zero.sub(withdrawAmount)]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(withdrawAmount));
  });

  it("redeem: from pending ape coin", async () => {
    const withdrawAmount = await contracts.bendCoinPool.balanceOf(bob.address);
    const apeCoinAmount = await contracts.bendCoinPool.previewRedeem(withdrawAmount);
    const tx = contracts.bendCoinPool.connect(bob).redeemSelf(withdrawAmount);
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [bob.address, contracts.bendCoinPool.address],
      [apeCoinAmount, constants.Zero.sub(apeCoinAmount)]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(apeCoinAmount));
  });

  it("pullApeCoin", async () => {
    const pullAmount = (await contracts.bendCoinPool.pendingApeCoin()).sub(makeBN18(1));
    const tx = contracts.bendCoinPool.connect(stakeManagerSigner).pullApeCoin(pullAmount);
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [contracts.bendCoinPool.address, contracts.bendStakeManager.address],
      [constants.Zero.sub(pullAmount), pullAmount]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(pullAmount));

    lastRevert = "pullApeCoin";
    await snapshots.capture(lastRevert);
  });

  it("withdraw: from withdraw strategy", async () => {
    const pendingApeCoin = await contracts.bendCoinPool.pendingApeCoin();
    const withdrawAmount = await contracts.bendCoinPool.assetBalanceOf(bob.address);
    const tx = contracts.bendCoinPool.connect(bob).withdrawSelf(withdrawAmount);
    await expect(tx).changeTokenBalances(contracts.wrapApeCoin, [bob.address], [withdrawAmount]);
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(withdrawAmount));
  });

  it("redeem: from withdraw strategy", async () => {
    const pendingApeCoin = await contracts.bendCoinPool.pendingApeCoin();
    const withdrawAmount = await contracts.bendCoinPool.balanceOf(bob.address);
    const apeCoinAmount = await contracts.bendCoinPool.previewRedeem(withdrawAmount);
    const tx = contracts.bendCoinPool.connect(bob).redeemSelf(withdrawAmount);
    await expect(tx).changeTokenBalances(contracts.wrapApeCoin, [bob.address], [apeCoinAmount]);
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(apeCoinAmount));
  });

  it("depositNativeSelf", async () => {
    let depositAmount = makeBN18(10000);
    let tx = contracts.bendCoinPool.connect(alice).depositNativeSelf({ value: depositAmount });
    await expect(tx).changeTokenBalances(contracts.wrapApeCoin, [contracts.bendCoinPool.address], [depositAmount]);
    await expectPendingAmountChanged((await tx).blockNumber || 0, depositAmount);

    lastRevert = "depositNativeSelf";
    await snapshots.capture(lastRevert);
  });

  it("withdrawNativeSelf", async () => {
    let depositAmount = makeBN18(10000);
    let tx = contracts.bendCoinPool.connect(alice).withdrawNativeSelf(depositAmount);
    await expect(tx).changeTokenBalances(
      contracts.wrapApeCoin,
      [contracts.bendCoinPool.address],
      [constants.Zero.sub(depositAmount)]
    );
    await expectPendingAmountChanged((await tx).blockNumber || 0, constants.Zero.sub(depositAmount));

    lastRevert = "withdrawNativeSelf";
    await snapshots.capture(lastRevert);
  });
});
