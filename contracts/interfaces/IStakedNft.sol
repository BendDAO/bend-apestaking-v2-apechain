// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721EnumerableUpgradeable.sol";

interface IStakedNft is IERC721MetadataUpgradeable, IERC721EnumerableUpgradeable {
    event Minted(address indexed to, uint256[] tokenId);
    event Burned(address indexed from, uint256[] tokenId);

    function authorise(address addr_, bool authorized_) external;

    function mint(address to, uint256[] calldata tokenIds) external;

    function burn(address from, uint256[] calldata tokenIds) external;

    /**
     * @dev Returns the staker of the `tokenId` token.
     */
    function stakerOf(uint256 tokenId) external view returns (address);

    /**
     * @dev Returns a token ID owned by `staker` at a given `index` of its token list.
     * Use along with {totalStaked} to enumerate all of ``staker``'s tokens.
     */

    function tokenOfStakerByIndex(address staker, uint256 index) external view returns (uint256);

    /**
     * @dev Returns the total staked amount of tokens for staker.
     */
    function totalStaked(address staker) external view returns (uint256);

    function underlyingAsset() external view returns (address);

    function setBnftRegistry(address bnftRegistry_) external;

    function setDelegateCash(address delegate, uint256[] calldata tokenIds, bool value) external;

    function getDelegateCashForToken(uint256[] calldata tokenIds_) external view returns (address[][] memory);

    function setDelegateCashV2(address delegate, uint256[] calldata tokenIds, bool value) external;

    function getDelegateCashForTokenV2(uint256[] calldata tokenIds_) external view returns (address[][] memory);
}
