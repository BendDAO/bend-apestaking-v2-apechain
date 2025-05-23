/* eslint-disable @typescript-eslint/ban-ts-comment */
import { task } from "hardhat/config";
import { BendCoinPool, BendNftPool, BendStakeManager, INftVault, IStakedNft } from "../typechain-types";
import {
  AAVE_ADDRESS_PROVIDER,
  WAPE_COIN,
  APE_STAKING,
  BAKC,
  BAKC_REWARDS_SHARE_RATIO,
  BAYC,
  BAYC_REWARDS_SHARE_RATIO,
  BEACON,
  BEND_ADDRESS_PROVIDER,
  BENDV2_ADDRESS_PROVIDER,
  BNFT_REGISTRY,
  COIN_POOL_V1,
  DELEAGATE_CASH,
  FEE,
  FEE_RECIPIENT,
  getParams,
  MAYC,
  MAYC_REWARDS_SHARE_RATIO,
  STAKER_MANAGER_V1,
  DELEAGATE_CASH_V2,
} from "./config";
import {
  deployContract,
  deployImplementation,
  deployProxyContract,
  deployProxyContractWithoutInit,
  getContractAddressFromDB,
  getContractFromDB,
  getDeploySigner,
  waitForTx,
} from "./utils/helpers";
import { verifyEtherscanContract } from "./utils/verification";

task("deploy:mock:Tokens", "Deploy Mock ApeCoinStaking").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  // const wape = await deployContract("MockWAPE", [1069672766], true);
  // console.log("WAPE at:", wape.address);

  const bayc = await deployContract("MintableERC721", ["MockBAYC", "BAYC"], true, "MockBAYC");
  const mayc = await deployContract("MintableERC721", ["MockMAYC", "MAYC"], true, "MockMAYC");
  const bakc = await deployContract("MintableERC721", ["MockBAKC", "BAKC"], true, "MockBAKC");

  console.log("MockBAYC at:", bayc.address);
  console.log("MockMAYC at:", mayc.address);
  console.log("MockBAKC at:", bakc.address);

  console.log("!!!Remember to set the address in the config file.!!!");
});

task("deploy:mock:ApeCoinStaking", "Deploy Mock ApeCoinStaking").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const bayc = getParams(BAYC, network.name);
  const mayc = getParams(MAYC, network.name);
  const bakc = getParams(BAKC, network.name);

  // const beacon = await deployContract("MockBeacon", [], true);
  // console.log("Beacon at:", beacon.address);
  const beacon = getParams(BEACON, network.name);

  const apeStaking = await deployContract("ApeCoinStaking", [beacon, bayc, mayc, bakc], true);
  console.log("ApeCoinStaking at:", apeStaking.address);

  console.log("!!!Remember to set the address in the config file.!!!");
});

task("deploy:full:StakedNFT", "Deploy all contracts for staked nfts").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await run("deploy:NftVault");
  await run("deploy:StBAYC");
  await run("deploy:StMAYC");
  await run("deploy:StBAKC");
});

task("deploy:NftVault", "Deploy NftVault").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const wape = getParams(WAPE_COIN, network.name);
  const apeStaking = getParams(APE_STAKING, network.name);
  const delegateCash = getParams(DELEAGATE_CASH, network.name);

  await deployProxyContract("NftVault", [wape, apeStaking, delegateCash], true);
});

task("deploy:StBAYC", "Deploy StBAYC").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const bayc = getParams(BAYC, network.name);
  const nftVault = await getContractAddressFromDB("NftVault");

  await deployProxyContract("StBAYC", [bayc, nftVault], true);
});

task("deploy:StMAYC", "Deploy StMAYC").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const mayc = getParams(MAYC, network.name);
  const nftVault = await getContractAddressFromDB("NftVault");

  await deployProxyContract("StMAYC", [mayc, nftVault], true);
});

task("deploy:StBAKC", "Deploy StBAKC").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const bakc = getParams(BAKC, network.name);
  const nftVault = await getContractAddressFromDB("NftVault");

  await deployProxyContract("StBAKC", [bakc, nftVault], true);
});

task("deploy:full:staking", "Deploy all contracts for staking").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await run("deploy:BendCoinPool");
  await run("deploy:BendNftPool");
  await run("deploy:BendStakeManager");

  await run("deploy:config:BendCoinPool");
  await run("deploy:config:BendNftPool");
  await run("deploy:config:BendStakeManager");
  await run("deploy:config:Authorise");
});

task("deploy:full:strategy", "Deploy all contracts for strategy").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await run("deploy:BaycRewardsStrategy");
  await run("deploy:MaycRewardsStrategy");
  await run("deploy:BakcRewardsStrategy");
  await run("deploy:config:RewardsStrategy");

  await run("deploy:DefaultWithdrawStrategy");
  await run("deploy:config:WithdrawStrategy");
});

task("deploy:BendCoinPool", "Deploy BendCoinPool").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await deployProxyContractWithoutInit("BendCoinPool", [], true);
});

task("deploy:BendNftPool", "Deploy BendNftPool").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await deployProxyContractWithoutInit("BendNftPool", [], true);
});

task("deploy:BendStakeManager", "Deploy StakeManager").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");

  await deployProxyContractWithoutInit("BendStakeManager", [], true);
});

task("deploy:BaycRewardsStrategy", "Deploy BaycStrategy").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const shareRatio = getParams(BAYC_REWARDS_SHARE_RATIO, network.name);

  await deployContract("DefaultRewardsStrategy", [shareRatio], true, "BaycRewardsStrategy");
});

task("deploy:MaycRewardsStrategy", "Deploy MaycStrategy").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const shareRatio = getParams(MAYC_REWARDS_SHARE_RATIO, network.name);

  await deployContract("DefaultRewardsStrategy", [shareRatio], true, "MaycRewardsStrategy");
});

task("deploy:BakcRewardsStrategy", "Deploy BakcStrategy").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const shareRatio = getParams(BAKC_REWARDS_SHARE_RATIO, network.name);

  await deployContract("DefaultRewardsStrategy", [shareRatio], true, "BakcRewardsStrategy");
});

task("deploy:DefaultWithdrawStrategy", "Deploy DefaultWithdrawStrategy").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const apeStaking = getParams(APE_STAKING, network.name);
  const nftVault = await getContractAddressFromDB("NftVault");
  const coinPool = await getContractAddressFromDB("BendCoinPool");
  const stakeManager = await getContractAddressFromDB("BendStakeManager");

  await deployContract("DefaultWithdrawStrategy", [apeStaking, nftVault, coinPool, stakeManager], true);
});

task("deploy:BendNftLockup", "Deploy BendNftLockup")
  .addParam("nftVault", "The nftValut contract address")
  .setAction(async ({ nftVault }, { network, run }) => {
    await run("set-DRE");
    await run("compile");

    // This task should only be used for ETH mainnet or sepolia
    // The nftVault parameter must contract address on the ApeChain mainnet or curtis

    const bayc = getParams(BAYC, network.name);
    const mayc = getParams(MAYC, network.name);
    const bakc = getParams(BAKC, network.name);
    const delegationRegistryV2 = getParams(DELEAGATE_CASH_V2, network.name);

    await deployProxyContract("BendNftLockup", [nftVault, bayc, mayc, bakc, delegationRegistryV2], true);
  });

task("deploy:PoolViewer", "Deploy PoolViewer").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const apeStaking = getParams(APE_STAKING, network.name);
  const coinPool = await getContractAddressFromDB("BendCoinPool");
  const stakeManager = await getContractAddressFromDB("BendStakeManager");
  const bnftRegistry = getParams(BNFT_REGISTRY, network.name);
  const v2AddressProvider = getParams(BENDV2_ADDRESS_PROVIDER, network.name);

  await deployProxyContract("PoolViewer", [apeStaking, coinPool, stakeManager, bnftRegistry, v2AddressProvider], true);
});

task("deploy:StakedVoting", "Deploy Voting").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");

  const coinPool = await getContractAddressFromDB("BendCoinPool");
  const nftPool = await getContractAddressFromDB("BendNftPool");
  const stakeManager = await getContractAddressFromDB("BendStakeManager");
  const bnftRegistry = getParams(BNFT_REGISTRY, network.name);

  await deployContract("BendApeCoinStakedVoting", [coinPool, nftPool, stakeManager, bnftRegistry], true);
});

task("deploy:config:BendCoinPool", "Coinfig BendCoinPool").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const coinPool = await getContractFromDB<BendCoinPool>("BendCoinPool");

  const wape = getParams(WAPE_COIN, network.name);
  const apeStaking = getParams(APE_STAKING, network.name);
  const stakeManager = await getContractAddressFromDB("BendStakeManager");

  await waitForTx(await coinPool.connect(deployer).initialize(wape, apeStaking, stakeManager));

  console.log("ok");
});

task("deploy:config:BendNftPool", "Coinfig BendNftPool").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const nftPool = await getContractFromDB<BendNftPool>("BendNftPool");

  const apeStaking = getParams(APE_STAKING, network.name);
  const bnftRegistry = getParams(BNFT_REGISTRY, network.name);

  const coinPool = await getContractAddressFromDB("BendCoinPool");
  const stakeManager = await getContractAddressFromDB("BendStakeManager");

  const stBayc = await getContractAddressFromDB("StBAYC");
  const stMayc = await getContractAddressFromDB("StMAYC");
  const stBakc = await getContractAddressFromDB("StBAKC");

  await waitForTx(
    await nftPool.connect(deployer).initialize(bnftRegistry, apeStaking, coinPool, stakeManager, stBayc, stMayc, stBakc)
  );

  console.log("ok");
});

task("deploy:config:BendStakeManager", "Coinfig BendStakeManager").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const stakeManager = await getContractFromDB<BendStakeManager>("BendStakeManager");

  const apeStaking = getParams(APE_STAKING, network.name);
  const coinPool = await getContractAddressFromDB("BendCoinPool");
  const nftPool = await getContractAddressFromDB("BendNftPool");
  const nftVault = await getContractAddressFromDB("NftVault");

  const stBayc = await getContractAddressFromDB("StBAYC");
  const stMayc = await getContractAddressFromDB("StMAYC");
  const stBakc = await getContractAddressFromDB("StBAKC");

  const fee = getParams(FEE, network.name);
  const feeRecipient = getParams(FEE_RECIPIENT, network.name);

  await waitForTx(
    await stakeManager.connect(deployer).initialize(apeStaking, coinPool, nftPool, nftVault, stBayc, stMayc, stBakc)
  );

  await waitForTx(await stakeManager.connect(deployer).updateFee(fee));
  await waitForTx(await stakeManager.connect(deployer).updateFeeRecipient(feeRecipient));

  console.log("ok");
});

task("deploy:config:RewardsStrategy", "Coinfig RewardsStrategy").setAction(async (_, { network, run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const stakeManager = await getContractFromDB<BendStakeManager>("BendStakeManager");

  const bayc = getParams(BAYC, network.name);
  const mayc = getParams(MAYC, network.name);
  const bakc = getParams(BAKC, network.name);

  const baycStrategy = await getContractAddressFromDB("BaycRewardsStrategy");
  const maycStrategy = await getContractAddressFromDB("MaycRewardsStrategy");
  const bakcStrategy = await getContractAddressFromDB("BakcRewardsStrategy");

  await waitForTx(await stakeManager.connect(deployer).updateRewardsStrategy(bayc, baycStrategy));
  await waitForTx(await stakeManager.connect(deployer).updateRewardsStrategy(mayc, maycStrategy));
  await waitForTx(await stakeManager.connect(deployer).updateRewardsStrategy(bakc, bakcStrategy));

  console.log("ok");
});

task("deploy:config:WithdrawStrategy", "Coinfig WithdrawStrategy").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const stakeManager = await getContractFromDB<BendStakeManager>("BendStakeManager");

  const withdrawStrategy = await getContractAddressFromDB("DefaultWithdrawStrategy");

  await waitForTx(await stakeManager.connect(deployer).updateWithdrawStrategy(withdrawStrategy));

  console.log("ok");
});

task("deploy:config:Authorise", "Authorise stBAYC,stMAYC,stBAKC,NftVault").setAction(async (_, { run }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const stBayc = await getContractFromDB<IStakedNft>("StBAYC");
  const stMayc = await getContractFromDB<IStakedNft>("StMAYC");
  const stBakc = await getContractFromDB<IStakedNft>("StBAKC");
  const nftVault = await getContractFromDB<INftVault>("NftVault");

  const staker = await getContractAddressFromDB("BendStakeManager");

  await waitForTx(await stBayc.connect(deployer).authorise(staker, true));
  await waitForTx(await stMayc.connect(deployer).authorise(staker, true));
  await waitForTx(await stBakc.connect(deployer).authorise(staker, true));

  await waitForTx(await nftVault.connect(deployer).authorise(stBayc.address, true));
  await waitForTx(await nftVault.connect(deployer).authorise(stMayc.address, true));
  await waitForTx(await nftVault.connect(deployer).authorise(stBakc.address, true));
  await waitForTx(await nftVault.connect(deployer).authorise(staker, true));

  console.log("ok");
});

task("deploy:config:setBnftRegistry", "setBnftRegistry stBAYC,stMAYC,stBAKC").setAction(async (_, { run, network }) => {
  await run("set-DRE");
  await run("compile");
  const deployer = await getDeploySigner();
  const stBayc = await getContractFromDB<IStakedNft>("StBAYC");
  const stMayc = await getContractFromDB<IStakedNft>("StMAYC");
  const stBakc = await getContractFromDB<IStakedNft>("StBAKC");
  const bnftRegistry = getParams(BNFT_REGISTRY, network.name);

  await waitForTx(await stBayc.connect(deployer).setBnftRegistry(bnftRegistry));
  await waitForTx(await stMayc.connect(deployer).setBnftRegistry(bnftRegistry));
  await waitForTx(await stBakc.connect(deployer).setBnftRegistry(bnftRegistry));

  console.log("ok");
});

task("deploy:NewImpl", "Deploy new implmentation")
  .addParam("implid", "The new impl contract id")
  .setAction(async ({ implid }, { run }) => {
    await run("set-DRE");
    await run("compile");

    await deployImplementation(implid, true);

    console.log("ok");
  });

task("prepareUpgrade", "Deploy new implmentation for upgrade")
  .addParam("proxyid", "The proxy contract id")
  .addParam("implid", "The new impl contract id")
  .setAction(async ({ proxyid, implid }, { ethers, upgrades, run }) => {
    await run("set-DRE");
    await run("compile");
    const proxyAddress = await getContractAddressFromDB(proxyid);
    const upgradeable = await ethers.getContractFactory(implid);
    console.log(`Preparing ${proxyid} upgrade at proxy ${proxyAddress}`);
    // @ts-ignore
    const implAddress = await upgrades.prepareUpgrade(proxyAddress, upgradeable);
    console.log("Implmentation at:", implAddress);
    const adminAddress = await upgrades.erc1967.getAdminAddress(proxyAddress);
    console.log("Proxy admin at:", adminAddress);
    await verifyEtherscanContract(implAddress.toString(), []);
  });

task("upgrade", "upgrade contract")
  .addParam("proxyid", "The proxy contract id")
  .addOptionalParam("implid", "The new impl contract id")
  .addFlag("skipcheck", "Skip upgrade storage check or not")
  .setAction(async ({ skipcheck, proxyid, implid }, { ethers, upgrades, run }) => {
    await run("set-DRE");
    await run("compile");
    if (!implid) {
      implid = proxyid;
    }
    const proxyAddress = await getContractAddressFromDB(proxyid);
    const upgradeable = await ethers.getContractFactory(implid);
    console.log(`Preparing upgrade proxy ${proxyid}: ${proxyAddress} with new ${implid}`);
    // @ts-ignore
    const upgraded = await upgrades.upgradeProxy(proxyAddress, upgradeable, { unsafeSkipStorageCheck: !!skipcheck });
    await upgraded.deployed();
    const implAddress = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("New implmentation at: ", implAddress);
    await verifyEtherscanContract(implAddress, []);
  });

task("upgrade:NftVault", "upgrade contract").setAction(async (_, { ethers, upgrades, run }) => {
  await run("set-DRE");
  await run("compile");

  const proxyAddress = await getContractAddressFromDB("NftVault");
  console.log("Proxy at: ", proxyAddress);

  const upgradeable = await ethers.getContractFactory("NftVault");

  // @ts-ignore
  const upgraded = await upgrades.upgradeProxy(proxyAddress, upgradeable, {
    unsafeSkipStorageCheck: true,
    unsafeAllowLinkedLibraries: true,
  });
  await upgraded.deployed();

  const implAddress = await upgrades.erc1967.getImplementationAddress(upgraded.address);
  console.log("New implmentation at: ", implAddress);
  await verifyEtherscanContract(implAddress, []);
});

task("forceImport", "force import implmentation to proxy")
  .addParam("proxy", "The proxy address")
  .addParam("implid", "The new impl contract id")
  .setAction(async ({ proxy, implid }, { ethers, upgrades, run }) => {
    await run("set-DRE");
    await run("compile");
    const upgradeable = await ethers.getContractFactory(implid);
    console.log(`Import proxy: ${proxy} with ${implid}`);
    // @ts-ignore
    await upgrades.forceImport(proxy, upgradeable);
  });

task("verify:Impl", "verify implmentation")
  .addParam("impl", "The contract implementation address")
  .setAction(async ({ impl }, { run }) => {
    await run("set-DRE");
    await run("compile");

    await verifyEtherscanContract(impl, []);
  });

task("verify:Contract", "verify contract")
  .addParam("address", "The contract address")
  .addOptionalParam("args", "The contract constructor args")
  .addOptionalParam("contract", "The contract file path")
  .setAction(async ({ address, args, contract }, { run }) => {
    await run("set-DRE");
    await run("compile");

    const argsList = (args as string).split(",");

    await verifyEtherscanContract(address, argsList, contract);
  });
