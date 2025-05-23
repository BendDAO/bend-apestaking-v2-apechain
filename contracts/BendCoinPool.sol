// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ERC4626Upgradeable, IERC4626Upgradeable, IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {IApeCoinStaking} from "./interfaces/IApeCoinStaking.sol";
import {ICoinPool} from "./interfaces/ICoinPool.sol";
import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {IWAPE} from "./interfaces/IWAPE.sol";

contract BendCoinPool is
    ICoinPool,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC4626Upgradeable
{
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event UserRequestWithdrawAllSelfAssets(address indexed account, uint256 amount);

    IApeCoinStaking public apeCoinStaking;
    IERC20Upgradeable public wrapApeCoin;
    IStakeManager public staker;

    uint256 public override pendingApeCoin;
    mapping(address => uint256) public requestWithdrawAllTimestamps;
    uint40 public requestWithdrawAllInterval;

    modifier onlyStaker() {
        require(msg.sender == address(staker), "BendCoinPool: caller is not staker");
        _;
    }

    function initialize(address wrapApeCoin_, IApeCoinStaking apeStaking_, IStakeManager staker_) external initializer {
        wrapApeCoin = IERC20Upgradeable(wrapApeCoin_);
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC20_init("Bend Auto-compound ApeCoin", "bacAPE");
        __ERC4626_init(wrapApeCoin);

        apeCoinStaking = apeStaking_;
        staker = staker_;
        requestWithdrawAllInterval = 4 hours;
    }

    function setApeCoinStaking(address apeCoinStaking_) public onlyOwner {
        apeCoinStaking = IApeCoinStaking(apeCoinStaking_);
    }

    function getWrapApeCoin() external view override returns (address) {
        return address(wrapApeCoin);
    }

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        uint256 amount = pendingApeCoin;
        amount += staker.totalStakedApeCoin();
        return amount;
    }

    receive() external payable {
        if (address(wrapApeCoin) != msg.sender) {
            depositNativeSelf();
        }
    }

    function depositNativeSelf() public payable override returns (uint256) {
        IWAPE(address(wrapApeCoin)).deposit{value: msg.value}();
        IERC20Upgradeable(address(wrapApeCoin)).transfer(msg.sender, msg.value);

        return deposit(msg.value, msg.sender);
    }

    function withdrawNativeSelf(uint256 assets) public override returns (uint256) {
        uint256 shares = withdraw(assets, address(this), msg.sender);

        IWAPE(address(wrapApeCoin)).withdraw(assets);
        (bool success, ) = msg.sender.call{value: assets}("");
        if (!success) revert("BendCoinPool: NativeTransferFailed");

        return shares;
    }

    function mintSelf(uint256 shares) external override returns (uint256) {
        return mint(shares, msg.sender);
    }

    function depositSelf(uint256 assets) external override returns (uint256) {
        return deposit(assets, msg.sender);
    }

    function withdrawSelf(uint256 assets) external override returns (uint256) {
        return withdraw(assets, msg.sender, msg.sender);
    }

    function redeemSelf(uint256 shares) external override returns (uint256) {
        return redeem(shares, msg.sender, msg.sender);
    }

    function redeemNative(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 assets = redeem(shares, address(this), owner);

        IWAPE(address(wrapApeCoin)).withdraw(assets);
        (bool success, ) = receiver.call{value: assets}("");
        if (!success) revert("BendCoinPool: NativeTransferFailed");

        return assets;
    }

    function requestWithdrawAllSelfAssets() public returns (uint256) {
        // check if the last request time is more than X hours
        uint256 lastReqTime_ = requestWithdrawAllTimestamps[msg.sender];
        require(
            block.timestamp > (lastReqTime_ + requestWithdrawAllInterval),
            "BendCoinPool: request withdraw all too fast"
        );

        requestWithdrawAllTimestamps[msg.sender] = block.timestamp;

        _compoundApeCoin();

        uint256 assets = assetBalanceOf(msg.sender);
        _withdrawApeCoin(assets);

        emit UserRequestWithdrawAllSelfAssets(msg.sender, assets);

        return assets;
    }

    function isRequestWithdrawAllSelfAssetsExpired(address account_) public view returns (bool, uint256) {
        uint256 lastReqTime_ = requestWithdrawAllTimestamps[account_];
        uint256 expiredTime_ = lastReqTime_ + requestWithdrawAllInterval;

        bool isExpired_ = block.timestamp > expiredTime_;

        if (lastReqTime_ == 0) {
            expiredTime_ = 0;
        }
        return (isExpired_, expiredTime_);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override(ERC4626Upgradeable) nonReentrant whenNotPaused {
        require(pendingApeCoin >= assets, "BendCoinPool: not enough assets");

        // transfer ape coin to receiver
        super._withdraw(caller, receiver, owner, assets, shares);

        // decrease pending amount
        pendingApeCoin -= assets;
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override(ERC4626Upgradeable) nonReentrant whenNotPaused {
        require(
            (totalSupply() > 0) || (msg.sender == staker.feeRecipient()),
            "BendCoinPool: only feeRecipient can deposit first"
        );

        // transfer ape coin from caller
        super._deposit(caller, receiver, assets, shares);

        // increase pending amount
        pendingApeCoin += assets;
    }

    function _withdrawApeCoin(uint256 assets) internal {
        if (pendingApeCoin < assets) {
            uint256 required = assets - pendingApeCoin;
            staker.withdrawApeCoin(required);
        }
    }

    function assetBalanceOf(address account) public view override returns (uint256) {
        return convertToAssets(balanceOf(account));
    }

    function assetWithdrawableOf(address account) public view returns (uint256) {
        uint256 assets = convertToAssets(balanceOf(account));
        if (pendingApeCoin < assets) {
            assets = pendingApeCoin;
        }
        return assets;
    }

    function receiveApeCoin(uint256 principalAmount, uint256 rewardsAmount_) external override onlyStaker {
        uint256 totalAmount = principalAmount + rewardsAmount_;
        wrapApeCoin.safeTransferFrom(msg.sender, address(this), totalAmount);
        pendingApeCoin += totalAmount;
        if (rewardsAmount_ > 0) {
            emit RewardDistributed(rewardsAmount_);
        }
    }

    function pullApeCoin(uint256 amount_) external override onlyStaker {
        require(pendingApeCoin >= amount_, "BendCoinPool: not enough pending apecoin");
        pendingApeCoin -= amount_;
        wrapApeCoin.safeTransfer(address(staker), amount_);
    }

    function compoundApeCoin() external override onlyStaker {
        _compoundApeCoin();
    }

    function _compoundApeCoin() internal {
        // WAPE has native yield, we need distribute it to holders through rebalance.
        // The pendingApeCoin should less or equal (<=) than WAPE balance.
        // We can not remove pendingApeCoin field to avoid attack like flash loan.
        pendingApeCoin = wrapApeCoin.balanceOf(address(this));
    }

    function setPause(bool flag) public onlyOwner {
        if (flag) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setRequestWithdrawAllInterval(uint40 interval) public onlyOwner {
        requestWithdrawAllInterval = interval;
    }
}
