// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IApeCoinStaking} from "../interfaces/IApeCoinStaking.sol";
import {INftVault} from "../interfaces/INftVault.sol";
import {ICoinPool} from "../interfaces/ICoinPool.sol";
import {INftPool, IStakedNft} from "../interfaces/INftPool.sol";
import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {IWithdrawStrategy} from "../interfaces/IWithdrawStrategy.sol";
import {IRewardsStrategy} from "../interfaces/IRewardsStrategy.sol";
import {IBNFTRegistry} from "../interfaces/IBNFTRegistry.sol";
import {IAddressProviderV2, IPoolLensV2} from "../interfaces/IBendV2Interfaces.sol";

import {ApeStakingLib} from "../libraries/ApeStakingLib.sol";

contract PoolViewer is OwnableUpgradeable {
    using ApeStakingLib for IApeCoinStaking;
    using Math for uint256;
    uint256 public constant PERCENTAGE_FACTOR = 1e4;
    uint public constant MODULEID__POOL_LENS = 4;

    struct PoolState {
        uint256 coinPoolPendingApeCoin;
        uint256 coinPoolPendingRewards;
        uint256 coinPoolStakedAmount;
        uint256 baycPoolMaxCap;
        uint256 maycPoolMaxCap;
        uint256 bakcPoolMaxCap;
    }

    struct PendingRewards {
        uint256 coinPoolRewards;
        uint256 baycPoolRewards;
        uint256 maycPoolRewards;
        uint256 bakcPoolRewards;
    }

    IApeCoinStaking public apeCoinStaking;
    IStakeManager public staker;
    ICoinPool public coinPool;
    IBNFTRegistry public bnftRegistry;

    address public bayc;
    address public mayc;
    address public bakc;
    IAddressProviderV2 public v2AddressProvider;
    address public v2PoolManager;
    IPoolLensV2 public v2PoolLens;

    function initialize(
        IApeCoinStaking apeCoinStaking_,
        ICoinPool coinPool_,
        IStakeManager staker_,
        IBNFTRegistry bnftRegistry_,
        IAddressProviderV2 v2AddressProvider_
    ) external initializer {
        __Ownable_init();

        apeCoinStaking = apeCoinStaking_;
        coinPool = coinPool_;
        staker = staker_;
        bnftRegistry = bnftRegistry_;

        bayc = address(apeCoinStaking.bayc());
        mayc = address(apeCoinStaking.mayc());
        bakc = address(apeCoinStaking.bakc());

        v2AddressProvider = v2AddressProvider_;
        if (v2AddressProvider != IAddressProviderV2(address(0))) {
            v2PoolManager = v2AddressProvider.getPoolManager();
            v2PoolLens = IPoolLensV2(v2AddressProvider.getPoolModuleProxy(MODULEID__POOL_LENS));
        }
    }

    function setApeCoinStaking(address apeCoinStaking_) public onlyOwner {
        apeCoinStaking = IApeCoinStaking(apeCoinStaking_);

        bayc = address(apeCoinStaking.bayc());
        mayc = address(apeCoinStaking.mayc());
        bakc = address(apeCoinStaking.bakc());
    }

    function setBendV2AddressProvider(IAddressProviderV2 v2AddressProvider_) public onlyOwner {
        v2AddressProvider = v2AddressProvider_;
        if (v2AddressProvider != IAddressProviderV2(address(0))) {
            v2PoolManager = v2AddressProvider.getPoolManager();
            v2PoolLens = IPoolLensV2(v2AddressProvider.getPoolModuleProxy(MODULEID__POOL_LENS));
        } else {
            v2PoolManager = address(0);
            v2PoolLens = IPoolLensV2(address(0));
        }
    }

    function viewPool() external view returns (PoolState memory poolState) {
        poolState.coinPoolPendingApeCoin = coinPool.pendingApeCoin();
        poolState.coinPoolPendingRewards = staker.pendingRewards(0);
        poolState.coinPoolStakedAmount = staker.stakedApeCoin(0);

        (
            IApeCoinStaking.PoolUI memory baycPoolUI,
            IApeCoinStaking.PoolUI memory maycPoolUI,
            IApeCoinStaking.PoolUI memory bakcPoolUI
        ) = apeCoinStaking.getPoolsUI();
        poolState.baycPoolMaxCap = baycPoolUI.currentTimeRange.capPerPosition;
        poolState.maycPoolMaxCap = maycPoolUI.currentTimeRange.capPerPosition;
        poolState.bakcPoolMaxCap = bakcPoolUI.currentTimeRange.capPerPosition;
    }

    function viewNftPoolPendingRewards(
        address nft_,
        uint256[] calldata tokenIds_
    ) external view returns (uint256 rewards) {
        uint256 poolId = apeCoinStaking.getNftPoolId(nft_);
        uint256 reward;
        for (uint256 i; i < tokenIds_.length; i++) {
            reward = apeCoinStaking.pendingRewards(poolId, tokenIds_[i]);
            rewards += reward;
        }
        rewards -= staker.calculateFee(rewards);
    }

    function viewBakcPairingStatus(
        uint256[] calldata baycTokenIds_,
        uint256[] calldata maycTokenIds_
    ) external pure returns (bool[] memory baycPairs, bool[] memory maycPairs) {
        baycPairs = new bool[](baycTokenIds_.length);
        maycPairs = new bool[](maycTokenIds_.length);
        uint256 tokenId_;
        for (uint256 i = 0; i < baycTokenIds_.length; i++) {
            tokenId_ = baycTokenIds_[i];
            //baycPairs[i] = apeCoinStaking.mainToBakc(ApeStakingLib.BAYC_POOL_ID, tokenId_).isPaired;
        }
        for (uint256 i = 0; i < maycTokenIds_.length; i++) {
            tokenId_ = maycTokenIds_[i];
            //maycPairs[i] = apeCoinStaking.mainToBakc(ApeStakingLib.MAYC_POOL_ID, tokenId_).isPaired;
        }
    }

    function viewPoolPendingRewards() public view returns (PendingRewards memory rewards) {
        rewards.coinPoolRewards = staker.pendingRewards(ApeStakingLib.APE_COIN_POOL_ID);

        // bayc
        rewards.baycPoolRewards = staker.pendingRewards(ApeStakingLib.BAYC_POOL_ID);
        uint256 coinRewards = rewards.baycPoolRewards.mulDiv(
            PERCENTAGE_FACTOR - staker.getNftRewardsShare(bayc),
            PERCENTAGE_FACTOR,
            Math.Rounding.Down
        );
        rewards.baycPoolRewards -= coinRewards;
        rewards.coinPoolRewards += coinRewards;

        // mayc
        rewards.maycPoolRewards = staker.pendingRewards(ApeStakingLib.MAYC_POOL_ID);
        coinRewards = rewards.maycPoolRewards.mulDiv(
            PERCENTAGE_FACTOR - staker.getNftRewardsShare(mayc),
            PERCENTAGE_FACTOR,
            Math.Rounding.Down
        );
        rewards.maycPoolRewards -= coinRewards;
        rewards.coinPoolRewards += coinRewards;

        // bakc
        rewards.bakcPoolRewards = staker.pendingRewards(ApeStakingLib.BAKC_POOL_ID);
        coinRewards = rewards.bakcPoolRewards.mulDiv(
            PERCENTAGE_FACTOR - staker.getNftRewardsShare(bakc),
            PERCENTAGE_FACTOR,
            Math.Rounding.Down
        );
        rewards.bakcPoolRewards -= coinRewards;
        rewards.coinPoolRewards += coinRewards;

        rewards.coinPoolRewards -= staker.calculateFee(rewards.coinPoolRewards);
        rewards.baycPoolRewards -= staker.calculateFee(rewards.baycPoolRewards);
        rewards.maycPoolRewards -= staker.calculateFee(rewards.maycPoolRewards);
        rewards.bakcPoolRewards -= staker.calculateFee(rewards.bakcPoolRewards);
    }

    function viewUserPendingRewards(address userAddr_) external view returns (PendingRewards memory rewards) {
        rewards = viewPoolPendingRewards();

        uint256 totalSupply = coinPool.totalSupply();
        if (totalSupply > 0) {
            rewards.coinPoolRewards = rewards.coinPoolRewards.mulDiv(
                coinPool.balanceOf(userAddr_),
                totalSupply,
                Math.Rounding.Down
            );
        }

        uint256 totalStakedNft = staker.stBayc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.baycPoolRewards = rewards.baycPoolRewards.mulDiv(
                getStakedNftCount(staker.stBayc(), userAddr_),
                totalStakedNft,
                Math.Rounding.Down
            );
        }

        totalStakedNft = staker.stMayc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.maycPoolRewards = rewards.maycPoolRewards.mulDiv(
                getStakedNftCount(staker.stMayc(), userAddr_),
                totalStakedNft,
                Math.Rounding.Down
            );
        }

        totalStakedNft = staker.stBakc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.bakcPoolRewards = rewards.bakcPoolRewards.mulDiv(
                getStakedNftCount(staker.stBakc(), userAddr_),
                totalStakedNft,
                Math.Rounding.Down
            );
        }
    }

    function getStakedNftCount(IStakedNft nft_, address userAddr_) public view returns (uint256 count) {
        for (uint256 i = 0; i < nft_.balanceOf(userAddr_); i++) {
            if (nft_.stakerOf(nft_.tokenOfOwnerByIndex(userAddr_, i)) == address(staker)) {
                count += 1;
            }
        }

        if (bnftRegistry == IBNFTRegistry(address(0))) {
            return count;
        }

        (address bnftProxy, ) = bnftRegistry.getBNFTAddresses(address(nft_));
        if (bnftProxy != address(0)) {
            IERC721Enumerable bnft = IERC721Enumerable(bnftProxy);
            for (uint256 i = 0; i < bnft.balanceOf(userAddr_); i++) {
                if (nft_.stakerOf(bnft.tokenOfOwnerByIndex(userAddr_, i)) == address(staker)) {
                    count += 1;
                }
            }
        }
    }

    function getStakedNftCountForBendV2(
        IStakedNft nft_,
        address userAddr_,
        uint32[] calldata v2PoolIds_
    ) public view returns (uint256 count) {
        count = getStakedNftCount(nft_, userAddr_);

        if (v2PoolLens == IPoolLensV2(address(0))) {
            return count;
        }

        for (uint i = 0; i < v2PoolIds_.length; i++) {
            (uint256 totalCrossSupply, uint256 totalIsolateSupply, , ) = v2PoolLens.getUserAssetData(
                userAddr_,
                v2PoolIds_[i],
                address(nft_)
            );
            count += (totalCrossSupply + totalIsolateSupply);
        }
    }

    function getAllStakedNftCountForBendV2(
        address userAddr_,
        uint32[] calldata v2PoolIds_
    ) public view returns (uint256 baycNum, uint256 maycNum, uint256 bakcNum) {
        baycNum = getStakedNftCountForBendV2(staker.stBayc(), userAddr_, v2PoolIds_);
        maycNum = getStakedNftCountForBendV2(staker.stMayc(), userAddr_, v2PoolIds_);
        bakcNum = getStakedNftCountForBendV2(staker.stBakc(), userAddr_, v2PoolIds_);
    }

    function viewUserPendingRewardsForBendV2(
        address userAddr_,
        uint32[] calldata v2PoolIds_
    ) public view returns (PendingRewards memory rewards) {
        rewards = viewPoolPendingRewards();

        uint256 totalSupply = coinPool.totalSupply();
        if (totalSupply > 0) {
            rewards.coinPoolRewards = rewards.coinPoolRewards.mulDiv(
                coinPool.balanceOf(userAddr_),
                totalSupply,
                Math.Rounding.Down
            );
        }

        (uint256 baycNum, uint256 maycNum, uint256 bakcNum) = getAllStakedNftCountForBendV2(userAddr_, v2PoolIds_);

        uint256 totalStakedNft = staker.stBayc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.baycPoolRewards = rewards.baycPoolRewards.mulDiv(baycNum, totalStakedNft, Math.Rounding.Down);
        }

        totalStakedNft = staker.stMayc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.maycPoolRewards = rewards.maycPoolRewards.mulDiv(maycNum, totalStakedNft, Math.Rounding.Down);
        }

        totalStakedNft = staker.stBakc().totalStaked(address(staker));
        if (totalStakedNft > 0) {
            rewards.bakcPoolRewards = rewards.bakcPoolRewards.mulDiv(bakcNum, totalStakedNft, Math.Rounding.Down);
        }
    }

    function getPoolUIByIndex(uint256 poolId_, uint256 index_) public view returns (IApeCoinStaking.PoolUI memory) {
        IApeCoinStaking.PoolWithoutTimeRange memory poolNoTR = apeCoinStaking.pools(poolId_);
        IApeCoinStaking.TimeRange memory tr = apeCoinStaking.getTimeRangeBy(poolId_, index_);
        return IApeCoinStaking.PoolUI(poolId_, poolNoTR.stakedAmount, tr);
    }

    function getPoolUIByID(uint256 poolId_) public view returns (IApeCoinStaking.PoolUI memory) {
        if (poolId_ == ApeStakingLib.APE_COIN_POOL_ID) {
            return IApeCoinStaking.PoolUI(poolId_, 0, IApeCoinStaking.TimeRange(0, 0, 0, 0));
        }

        IApeCoinStaking.PoolWithoutTimeRange memory poolNoTR = apeCoinStaking.pools(poolId_);
        IApeCoinStaking.TimeRange memory tr = apeCoinStaking.getTimeRangeBy(poolId_, poolNoTR.lastRewardsRangeIndex);
        return IApeCoinStaking.PoolUI(poolId_, poolNoTR.stakedAmount, tr);
    }

    function getPoolsUI()
        public
        view
        returns (
            IApeCoinStaking.PoolUI memory,
            IApeCoinStaking.PoolUI memory,
            IApeCoinStaking.PoolUI memory,
            IApeCoinStaking.PoolUI memory
        )
    {
        return (
            getPoolUIByID(ApeStakingLib.APE_COIN_POOL_ID),
            getPoolUIByID(ApeStakingLib.BAYC_POOL_ID),
            getPoolUIByID(ApeStakingLib.MAYC_POOL_ID),
            getPoolUIByID(ApeStakingLib.BAKC_POOL_ID)
        );
    }

    function getNftPositionList(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_
    ) public view returns (uint256[][] memory stakedAmounts) {
        uint256 poolId_;
        address nft_;
        uint256 tokenId_;
        IApeCoinStaking.Position memory position_;

        require(nfts_.length == tokenIds_.length, "PoolViewer: inconsistent length");

        stakedAmounts = new uint256[][](nfts_.length);
        for (uint256 i = 0; i < nfts_.length; i++) {
            nft_ = nfts_[i];
            poolId_ = apeCoinStaking.getNftPoolId(nft_);

            stakedAmounts[i] = new uint256[](tokenIds_[i].length);
            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                tokenId_ = tokenIds_[i][j];
                position_ = apeCoinStaking.nftPosition(poolId_, tokenId_);
                stakedAmounts[i][j] = position_.stakedAmount;
            }
        }

        return stakedAmounts;
    }
}
