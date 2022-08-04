//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVault {

    function initialize(
        uint256 _vaultVersion,
        uint256 nonce,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external;

    /// @notice Turn the emissions on and off
    /// @dev Only callable by the factory contract
    /// @param _nft Address of NFT collection
    /// @param _id ID of NFT
    /// @param emissionStatus The state new state of 'emissionsStarted' 
    function toggleEmissions(address _nft, uint256 _id, bool emissionStatus) external;

    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] calldata _compTokenInfo) external;

    /// @notice [setup phase] Start the pools operation
    /// @param slots The amount of collateral slots the pool will offer
    function begin(uint256 slots) external;

    /// @notice Purchase an LP position in a spot pool
    /// @dev Each position that is held by a user is tagged by a nonce which allows each 
    /// position to hold the property of a pseudo non-fungible token (psuedo because it 
    /// doesn't directly follow the common ERC721 token standard). This position is tradeable
    /// post-purchase via the 'transferFrom' function. 
    /// - The '_caller' address of a purchase receives a 1% referral fee. If this is the buyer,
    /// they incur no fee as the extra 1% is accredited to them. 
    /// @param _caller Function caller
    /// @param _buyer The position buyer
    /// @param tickets Array of tickets that the buyer would like to add in their position
    /// @param amountPerTicket Array of amount of tokens that the buyer would like to purchase
    /// from each ticket
    /// @param startEpoch Starting LP epoch
    /// @param finalEpoch The first epoch during which the LP position unlocks
    function purchase(
        address _caller,
        address _buyer, 
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) external payable;

    /// @notice Close an LP position and receive credits earned
    /// @dev Users ticket balances are counted on a risk adjusted basis in comparison to the
    /// maximum purchased ticket tranche. The lowest discounted EDC payout is 75% and the 
    /// highest premium is 125% for the highest ticket holders. This rate effects the portion of
    /// EDC that a user receives per EDC emitted from a pool each epoch. Furthermore, upon unlock
    /// any concentrated or general bribes during the users LP time is distributed on a risk
    /// adjusted basis. Revenues from an EDC sale are distributed among allocators.
    /// @param _user Address of the LP
    /// @param _nonce Held nonce to close 
    /// @param _payoutRatio Ratio of mined EDC that the user would like to purchase 
    function sell(
        address _user,
        uint256 _nonce,
        uint256 _payoutRatio
    ) external;

    /// @notice Offer a bribe to all LPs during a set of epochs
    /// @param bribePerEpoch Bribe size during each desired epoch
    /// @param startEpoch First epoch where bribes will be distributed
    /// @param endEpoch Epoch in which bribe distribution from this general
    /// bribe concludes
    function offerGeneralBribe(
        uint256 bribePerEpoch, 
        uint256 startEpoch, 
        uint256 endEpoch
    ) external payable;

    /// @notice Offer a concentrated bribe
    /// @dev Concentrated bribes are offered to specific tranches during specific epochs 
    /// @param startEpoch First epoch where bribes will be distributed
    /// @param endEpoch Epoch in which bribe distribution from this general
    /// @param tickets Tranches for bribe to be applied
    /// @param bribePerTicket Size of the bribe offered to each tranche LP
    function offerConcentratedBribe(
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] calldata tickets,
        uint256[] calldata bribePerTicket
    ) external payable;

    /// @notice Reclaim unused general bribes offered
    /// @param epoch Epoch in which bribe went unused
    function reclaimGeneralBribe(uint256 epoch) external;

    /// @notice Reclaim unused concentrated bribes offered
    /// @param epoch Epoch in which bribe went unused
    /// @param ticket Ticket in which bribe went unused
    function reclaimConcentratedBribe(uint256 epoch, uint256 ticket) external;

    /// @notice Revoke an NFTs connection to a pool
    /// @param _nft List of NFTs to be removed
    /// @param _id List of token ID of the NFT to be removed
    function remove(address[] calldata _nft, uint256[] calldata _id) external;

    /// @notice Update the 'totAvailFunds' count upon the conclusion of an auction
    /// @dev Called automagically by the closure contract 
    /// @param _nft NFT that was auctioned off
    /// @param _id Token ID of the NFT that was auctioned off
    /// @param _saleValue Auction sale value
    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external payable;

    /// @notice Reset the value of 'payoutPerRes' size and the total allowed reservations
    /// @dev This rebalances the payout per reservation value dependent on the total 
    /// available funds count. 
    function restore() external returns(bool);

    /// @notice Reserve the ability to close an NFT during an epoch 
    /// @dev Example: Alice and Bob create a 1 slot pool together with 2 Punks. Alice wants to
    /// borrow against the NFT in the upcoming epoch so she reserves the right to close the pool via 
    /// 'reserve'. If Bob wants to close the NFT he has to wait until he can reserve the closure space.
    /// The cost to reserve also increases by 25% based on the amount of reservations that have been
    /// made during the epoch of interest. So if the pool was created with 2 slots and Alice already
    /// reserved a space, Bob would have to pay 125% of what Alice paid to take the second reservation
    /// slot. 
    /// @param _nft NFT that is being reserved
    /// @param id Token ID of the NFT that is being reserved
    /// @param endEpoch The epoch during which the reservation wears off
    function reserve(address _nft, uint256 id, uint256 endEpoch) external payable;

    /// @notice Allow another user permission to execute a single 'transferFrom' call
    /// @param recipient Allowee address
    /// @param nonce Nonce of allowance 
    function changeTransferPermission(
        address recipient,
        uint256 nonce,
        bool permission
    ) external;

    /// @notice Transfer a position or portion of a position from one user to another
    /// @dev A user can transfer an amount of tokens in each tranche from their held position at
    /// 'nonce' to another users new position (upon transfer a new position (with a new nonce)
    /// is created for the 'to' address). 
    /// @param from Sender 
    /// @param to Recipient
    /// @param nonce Nonce of position that transfer is being applied
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external;

    /// @notice Close an NFT in exchange for the 'payoutPerRes' of the current epoch
    /// @dev This closure triggers a 48 hour auction to begin in which the closed NFT will be sold
    /// and can only be called by the holder of the NFT. Upon calling this function the caller will
    /// be sent the 'payoutPerRes' and the NFT will be taken. (If this is the first function call)
    /// it will create a close pool contract that the rest of the closure will use as well.
    /// @param _nft NFT that is being closed
    /// @param _id Token ID of the NFT that is being closed
    function closeNft(address _nft, uint256 _id) external;

    /// @notice Close the pool
    /// @dev This can only be called from the factory once majority of holders
    /// sign off on the overall closure of this pool.
    function closePool() external;

    /// @notice Adjust a users LP information after an NFT is closed
    /// @dev This function is called by the calculate principal function in the closure contract
    /// @param _user Address of the LP owner
    /// @param _nonce Nonce of the LP
    /// @param _nft Address of the auctioned NFT
    /// @param _id Token ID of the auctioned NFT
    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external returns(bool);

    /// @notice Get multi asset pool reference nonce
    function getNonce() external view returns(uint256);

    /// @notice Get the list of NFT address and corresponding token IDs in by this pool
    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool);

    /// @notice Get the amount of spots in a ticket that have been purchased during an epoch
    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256);

    /// @notice Get the cost to reserve an NFT for an amount of epochs
    /// @dev This takes into account the reservation amount premiums
    /// @param _endEpoch The epoch after the final reservation epoch
    function getCostToReserve(uint256 _endEpoch) external view returns(uint256);
}