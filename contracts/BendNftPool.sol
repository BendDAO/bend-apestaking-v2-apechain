// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {INftVault} from "./interfaces/INftVault.sol";
import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {INftPool, IStakedNft, IApeCoinStaking} from "./interfaces/INftPool.sol";
import {ICoinPool} from "./interfaces/ICoinPool.sol";
import {IBNFTRegistry} from "./interfaces/IBNFTRegistry.sol";
import {IAddressProviderV2, IPoolLensV2} from "./interfaces/IBendV2Interfaces.sol";
import {IWAPE} from "./interfaces/IWAPE.sol";

contract BendNftPool is INftPool, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for ICoinPool;
    uint256 private constant APE_COIN_PRECISION = 1e18;
    uint private constant MODULEID__POOL_LENS = 4;

    IApeCoinStaking public apeCoinStaking;
    IERC20Upgradeable public wrapApeCoin;
    mapping(address => PoolState) public poolStates;
    IStakeManager public override staker;
    ICoinPool public coinPool;
    address public bayc;
    address public mayc;
    address public bakc;
    IBNFTRegistry public bnftRegistry;
    IAddressProviderV2 public v2AddressProvider;
    address public v2PoolManager;
    IPoolLensV2 public v2PoolLens;

    modifier onlyApe(address nft_) {
        require(bayc == nft_ || mayc == nft_ || bakc == nft_, "BendNftPool: not ape");
        _;
    }

    modifier onlyApes(address[] calldata nfts_) {
        address nft_;
        for (uint256 i = 0; i < nfts_.length; i++) {
            nft_ = nfts_[i];
            require(bayc == nft_ || mayc == nft_ || bakc == nft_, "BendNftPool: not ape");
        }
        _;
    }

    modifier onlyStaker() {
        require(msg.sender == address(staker), "BendNftPool: caller is not staker");
        _;
    }

    function initialize(
        IBNFTRegistry bnftRegistry_,
        IApeCoinStaking apeStaking_,
        ICoinPool coinPool_,
        IStakeManager staker_,
        IStakedNft stBayc_,
        IStakedNft stMayc_,
        IStakedNft stBakc_
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        apeCoinStaking = apeStaking_;

        staker = staker_;
        coinPool = coinPool_;
        bnftRegistry = bnftRegistry_;

        bayc = stBayc_.underlyingAsset();
        mayc = stMayc_.underlyingAsset();
        bakc = stBakc_.underlyingAsset();
        poolStates[bayc].stakedNft = stBayc_;
        poolStates[mayc].stakedNft = stMayc_;
        poolStates[bakc].stakedNft = stBakc_;

        wrapApeCoin = IERC20Upgradeable(coinPool.getWrapApeCoin());
        wrapApeCoin.approve(address(coinPool), type(uint256).max);
    }

    function setApeCoinStaking(address apeCoinStaking_) public onlyOwner {
        apeCoinStaking = IApeCoinStaking(apeCoinStaking_);
    }

    function setStNftAddresses(IStakedNft stBayc_, IStakedNft stMayc_, IStakedNft stBakc_) public onlyOwner {
        bayc = stBayc_.underlyingAsset();
        mayc = stMayc_.underlyingAsset();
        bakc = stBakc_.underlyingAsset();
        poolStates[bayc].stakedNft = stBayc_;
        poolStates[mayc].stakedNft = stMayc_;
        poolStates[bakc].stakedNft = stBakc_;
    }

    function deposit(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_,
        address owner_
    ) external override onlyApes(nfts_) onlyStaker nonReentrant whenNotPaused {
        address nft_;
        uint256 tokenId_;
        PoolState storage pool_;

        require(owner_ != address(0), "BendNftPool: zero owner");
        _checkDuplicateNfts(nfts_);
        _checkDuplicateTokenIds(tokenIds_);

        for (uint256 i = 0; i < nfts_.length; i++) {
            nft_ = nfts_[i];
            pool_ = poolStates[nft_];
            _compoundApeCoin(pool_);

            require(tokenIds_[i].length > 0, "BendNftPool: empty tokenIds");
            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                tokenId_ = tokenIds_[i][j];
                pool_.rewardsDebt[tokenId_] = pool_.accumulatedRewardsPerNft;
            }

            staker.mintStNft(pool_.stakedNft, owner_, tokenIds_[i]);

            emit NftDeposited(nft_, tokenIds_[i], owner_);
        }
    }

    function withdraw(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_,
        address owner_
    ) external override onlyApes(nfts_) onlyStaker nonReentrant whenNotPaused {
        require(owner_ != address(0), "BendNftPool: zero owner");
        _checkDuplicateNfts(nfts_);
        _checkDuplicateTokenIds(tokenIds_);

        uint32[][] memory v2PoolIds_ = new uint32[][](0);
        _claim(owner_, owner_, nfts_, tokenIds_, v2PoolIds_);

        PoolState storage pool_;
        uint256 tokenId_;
        address nft_;

        for (uint256 i = 0; i < nfts_.length; i++) {
            require(tokenIds_[i].length > 0, "BendNftPool: empty tokenIds");

            nft_ = nfts_[i];
            pool_ = poolStates[nft_];

            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                tokenId_ = tokenIds_[i][j];
                require(pool_.stakedNft.ownerOf(tokenId_) == owner_, "BendNftPool: invalid owner");
            }

            staker.burnStNft(pool_.stakedNft, owner_, tokenIds_[i]);

            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                tokenId_ = tokenIds_[i][j];
                delete pool_.rewardsDebt[tokenId_];
            }

            emit NftWithdrawn(nft_, tokenIds_[i], owner_);
        }
    }

    function _claim(
        address owner_,
        address receiver_,
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_,
        uint32[][] memory v2PoolIds_
    ) internal {
        address nft_;
        PoolState storage pool_;
        uint256 tokenId_;
        uint256 claimableShares;
        uint256 totalClaimableShares;
        address tokenOwner_;

        for (uint256 i = 0; i < nfts_.length; i++) {
            if (tokenIds_[i].length == 0) {
                continue;
            }
            if (v2PoolIds_.length > 0) {
                require(v2PoolIds_[i].length == tokenIds_[i].length, "BendNftPool: invalid v2PoolIds");
            }
            nft_ = nfts_[i];
            pool_ = poolStates[nft_];
            (address bnftProxy, ) = bnftRegistry.getBNFTAddresses(address(pool_.stakedNft));
            claimableShares = 0;

            _compoundApeCoin(pool_);

            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                tokenId_ = tokenIds_[i][j];
                tokenOwner_ = pool_.stakedNft.ownerOf(tokenId_);
                if (tokenOwner_ != owner_ && bnftProxy != address(0) && tokenOwner_ == bnftProxy) {
                    tokenOwner_ = IERC721Upgradeable(bnftProxy).ownerOf(tokenId_);
                }
                // special case for stNFT deposited in v2 protocol
                if (v2PoolIds_.length > 0) {
                    if (
                        tokenOwner_ != owner_ &&
                        address(v2PoolManager) != address(0) &&
                        tokenOwner_ == address(v2PoolManager)
                    ) {
                        (tokenOwner_, , ) = v2PoolLens.getERC721TokenData(
                            v2PoolIds_[i][j],
                            address(pool_.stakedNft),
                            tokenId_
                        );
                    }
                }
                require(tokenOwner_ == owner_, "BendNftPool: invalid token owner");
                require(pool_.stakedNft.stakerOf(tokenId_) == address(staker), "BendNftPool: invalid token staker");

                claimableShares += _calculateRewards(pool_.accumulatedRewardsPerNft, pool_.rewardsDebt[tokenId_]);
                // set token rewards debt with pool index
                pool_.rewardsDebt[tokenId_] = pool_.accumulatedRewardsPerNft;
            }
            if (claimableShares > 0) {
                emit NftRewardClaimed(
                    nft_,
                    tokenIds_[i],
                    receiver_,
                    coinPool.previewRedeem(claimableShares),
                    pool_.accumulatedRewardsPerNft
                );
            }

            totalClaimableShares += claimableShares;
        }

        if (totalClaimableShares > 0) {
            coinPool.redeemNative(totalClaimableShares, receiver_, address(this));
        }
    }

    function claim(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_
    ) external override onlyApes(nfts_) nonReentrant whenNotPaused {
        _checkDuplicateNfts(nfts_);
        _checkDuplicateTokenIds(tokenIds_);

        uint32[][] memory v2PoolIds_ = new uint32[][](0);

        _claim(msg.sender, msg.sender, nfts_, tokenIds_, v2PoolIds_);
    }

    function claimForBendV2(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_,
        uint32[][] calldata v2PoolIds_
    ) external onlyApes(nfts_) nonReentrant whenNotPaused {
        _checkDuplicateNfts(nfts_);
        _checkDuplicateTokenIds(tokenIds_);

        _claim(msg.sender, msg.sender, nfts_, tokenIds_, v2PoolIds_);
    }

    function receiveApeCoin(address nft_, uint256 rewardsAmount_) external override onlyApe(nft_) onlyStaker {
        wrapApeCoin.safeTransferFrom(msg.sender, address(this), rewardsAmount_);
        poolStates[nft_].pendingApeCoin += rewardsAmount_;
        if (rewardsAmount_ > 0) {
            emit NftRewardDistributed(nft_, rewardsAmount_);
        }
    }

    function _compoundApeCoin(PoolState storage pool_) internal {
        uint256 rewardsAmount_ = pool_.pendingApeCoin;
        if (rewardsAmount_ == 0) {
            return;
        }

        uint256 supply = pool_.stakedNft.totalStaked(address(staker));
        uint256 accumulatedShare = coinPool.deposit(rewardsAmount_, address(this));

        pool_.pendingApeCoin = 0;

        // In extreme cases all nft give up the earned rewards and exit
        if (supply > 0) {
            pool_.accumulatedRewardsPerNft = _calculatePoolIndex(
                pool_.accumulatedRewardsPerNft,
                accumulatedShare,
                supply
            );
        }
    }

    function compoundApeCoin(address nft_) external override onlyApe(nft_) onlyStaker {
        _compoundApeCoin(poolStates[nft_]);
    }

    function pendingApeCoin(address nft_) external view returns (uint256) {
        return poolStates[nft_].pendingApeCoin;
    }

    function claimable(
        address[] calldata nfts_,
        uint256[][] calldata tokenIds_
    ) public view override onlyApes(nfts_) returns (uint256 amount) {
        return _claimable(nfts_, tokenIds_);
    }

    function _claimable(address[] memory nfts_, uint256[][] memory tokenIds_) internal view returns (uint256 amount) {
        PoolState storage pool_;
        address nft_;
        uint256 accumulatedRewardsPerNft_;

        _checkDuplicateNfts(nfts_);
        _checkDuplicateTokenIds(tokenIds_);

        for (uint256 i = 0; i < nfts_.length; i++) {
            nft_ = nfts_[i];
            pool_ = poolStates[nft_];
            accumulatedRewardsPerNft_ = pool_.accumulatedRewardsPerNft;
            if (pool_.stakedNft.totalStaked(address(staker)) > 0) {
                accumulatedRewardsPerNft_ = _calculatePoolIndex(
                    accumulatedRewardsPerNft_,
                    coinPool.previewDeposit(pool_.pendingApeCoin),
                    pool_.stakedNft.totalStaked(address(staker))
                );
            }

            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                amount += _calculateRewards(accumulatedRewardsPerNft_, pool_.rewardsDebt[tokenIds_[i][j]]);
            }
        }
        if (amount != 0) {
            amount = coinPool.previewRedeem(amount);
        }
    }

    function claimableOf(address account_, address[] calldata nfts_) public view onlyApes(nfts_) returns (uint256) {
        address nft_;
        PoolState storage pool_;
        uint256 tokenNum_;
        uint256[][] memory tokenIds_ = new uint256[][](nfts_.length);

        for (uint256 nftIdx = 0; nftIdx < nfts_.length; nftIdx++) {
            nft_ = nfts_[nftIdx];
            pool_ = poolStates[nft_];

            tokenNum_ = pool_.stakedNft.balanceOf(account_);
            tokenIds_[nftIdx] = new uint256[](tokenNum_);
            for (uint256 tokenIdx = 0; tokenIdx < tokenNum_; tokenIdx++) {
                tokenIds_[nftIdx][tokenIdx] = pool_.stakedNft.tokenOfOwnerByIndex(account_, tokenIdx);
            }
        }

        return _claimable(nfts_, tokenIds_);
    }

    function assetWithdrawableOf(address account_, address[] calldata nfts_) public view returns (uint256) {
        uint256 claimableAmount = claimableOf(account_, nfts_);
        if (claimableAmount == 0) {
            return 0;
        }

        uint256 withdrawableAmount = coinPool.assetWithdrawableOf(address(this));
        if (claimableAmount > withdrawableAmount) {
            claimableAmount = withdrawableAmount;
        }

        return claimableAmount;
    }

    function _calculateRewards(
        uint256 accumulatedRewardsPerNft,
        uint256 rewardDebt
    ) internal pure returns (uint256 rewards) {
        if (accumulatedRewardsPerNft > rewardDebt) {
            rewards = (accumulatedRewardsPerNft - rewardDebt) / APE_COIN_PRECISION;
        }
    }

    function _calculatePoolIndex(
        uint256 accumulatedRewardsPerNft,
        uint256 accumulatedShare,
        uint256 nftSupply
    ) internal pure returns (uint256 rewards) {
        return accumulatedRewardsPerNft + ((accumulatedShare * APE_COIN_PRECISION) / nftSupply);
    }

    function _checkDuplicateNfts(address[] memory nfts_) internal pure {
        for (uint256 i = 0; i < nfts_.length; i++) {
            for (uint256 j = i + 1; j < nfts_.length; j++) {
                require(nfts_[i] != nfts_[j], "BendNftPool: duplicate nfts");
            }
        }
    }

    function _checkDuplicateTokenIds(uint256[][] memory tokenIds_) internal pure {
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            for (uint256 j = 0; j < tokenIds_[i].length; j++) {
                for (uint256 k = j + 1; k < tokenIds_[i].length; k++) {
                    require(tokenIds_[i][j] != tokenIds_[i][k], "BendNftPool: duplicate tokenIds");
                }
            }
        }
    }

    function getPoolStateUI(address nft_) external view returns (PoolUI memory poolUI) {
        PoolState storage pool = poolStates[nft_];
        poolUI.totalStakedNft = pool.stakedNft.totalStaked(address(staker));
        poolUI.accumulatedRewardsPerNft = pool.accumulatedRewardsPerNft;
        poolUI.pendingApeCoin = pool.pendingApeCoin;
    }

    function getNftStateUI(address nft_, uint256 tokenId) external view returns (uint256 rewardsDebt) {
        PoolState storage pool = poolStates[nft_];
        rewardsDebt = pool.rewardsDebt[tokenId];
    }

    function setPause(bool flag) public onlyOwner {
        if (flag) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setV2AddressProvider(address v2Provider_) public onlyOwner {
        v2AddressProvider = IAddressProviderV2(v2Provider_);
        v2PoolManager = v2AddressProvider.getPoolManager();
        v2PoolLens = IPoolLensV2(v2AddressProvider.getPoolModuleProxy(MODULEID__POOL_LENS));
    }

    function fixPoolState(address nft_, uint256 rewardsPerNft_) external onlyOwner {
        PoolState storage pool = poolStates[nft_];
        pool.accumulatedRewardsPerNft = rewardsPerNft_;
    }
}
