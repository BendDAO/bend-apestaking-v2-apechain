// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {NftVault} from "../../contracts/stakednft/NftVault.sol";

// how to run this testcase
// forge test --match-contract TestXxx --fork-url https://RPC --fork-block-number Nnn

contract TestFork25121801 is Test {
    address multiSigOwner;
    address bendStakeManager;
    ProxyAdmin proxyAdmin;
    NftVault nftVault;

    function setUp() public {
        multiSigOwner = 0x2a734c4343F4138C44B6Dde9e80390F068464712;
        bendStakeManager = 0x40E7Df7189Ef33711a4B0BFc3B4FDc7678B40d55;
        proxyAdmin = ProxyAdmin(0xe635D0fb1608aA54C3ca99c497E887d2e1E3E690);
        nftVault = NftVault(payable(0x79d922DD382E42A156bC0A354861cDBC4F09110d));
    }

    function _testFork_upgradeNftVault() public {
        // upgrading
        NftVault impl = new NftVault();
        vm.prank(multiSigOwner);
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(nftVault)), address(impl));

        // unstake
        uint256[] memory tokenIds_ = new uint256[](2);
        tokenIds_[0] = 8396;
        tokenIds_[1] = 9935;
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 856000000000000000000;
        amounts_[1] = 856000000000000000000;

        vm.prank(bendStakeManager);
        nftVault.unstakeBakcPool(tokenIds_, amounts_, address(this));
    }
}
