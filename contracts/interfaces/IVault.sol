//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {

    function initialize(
        string memory name,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external;

    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] calldata _compTokenInfo) external;

    /// @notice [setup phase] Start the pools operation
    /// @param _slots The amount of collateral slots the pool will offer
    /// @param _ticketSize The size of a tranche
    /// @param _rate The chosen interest rate
    function begin(uint256 _slots, uint256 _ticketSize, uint256 _rate) external payable;

    /// @notice Purchase an LP position in a spot pool
    /// @dev Each position that is held by a user is tagged by a nonce which allows each 
    /// position to hold the property of a pseudo non-fungible token (psuedo because it 
    /// doesn't directly follow the common ERC721 token standard). This position is tradeable
    /// post-purchase via the 'transferFrom' function. 
    /// - The '_caller' address of a purchase receives a 1% referral fee. If this is the buyer,
    /// they incur no fee as the extra 1% is accredited to them. 
    /// @param _buyer The position buyer
    /// @param tickets Array of tickets that the buyer would like to add in their position
    /// @param amountPerTicket Array of amount of tokens that the buyer would like to purchase
    /// from each ticket
    /// @param startEpoch Starting LP epoch
    /// @param finalEpoch The first epoch during which the LP position unlocks
    function purchase(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external payable;

    /// @notice Close an LP position and receive credits earned
    /// @dev Users ticket balances are counted on a risk adjusted basis in comparison to the
    /// maximum purchased ticket tranche. The lowest discounted EDC payout is 75% and the 
    /// highest premium is 125% for the highest ticket holders. This rate effects the portion of
    /// EDC that a user receives per EDC emitted from a pool each epoch.
    /// Revenues from an EDC sale are distributed among allocators.
    /// @param _user Address of the LP
    /// @param _nonce Held nonce to close 
    function sell(
        address _user,
        uint256 _nonce
    ) external returns(uint256 interestEarned);

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

    /// @notice Allow another user permission to execute a single 'transferFrom' call
    /// @param recipient Allowee address
    function changeTransferPermission(
        address recipient
    ) external returns(bool);

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
    ) external returns(bool);

    /// @notice Close an NFT in exchange for the 'payoutPerRes' of the current epoch
    /// @dev This closure triggers a 48 hour auction to begin in which the closed NFT will be sold
    /// and can only be called by the holder of the NFT. Upon calling this function the caller will
    /// be sent the 'payoutPerRes' and the NFT will be taken. (If this is the first function call)
    /// it will create a close pool contract that the rest of the closure will use as well.
    /// @param _nft NFT that is being closed
    /// @param _id Token ID of the NFT that is being closed
    function closeNft(address _nft, uint256 _id) external returns(uint256);

    /// @notice Adjust a users LP information after an NFT is closed
    /// @dev This function is called by the calculate principal function in the closure contract
    /// @param _user Address of the LP owner
    /// @param _nonce Nonce of the LP
    /// @param _nft Address of the auctioned NFT
    /// @param _id Token ID of the auctioned NFT
    /// @param _closureNonce Closure nonce of the NFT being adjusted for
    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external returns(bool);

    /// @notice Receive and process an fees earned by the Spot pool
    function processFees() external payable;

    /// @notice Send liquidity to borrower
    function accessLiq(address _user, address _nft, uint256 _id, uint256 _amount) external;

    /// @notice Receive liquidity from lending contract
    function depositLiq(address _nft, uint256 _id) external payable;

    /// @notice Get multi asset pool reference nonce
    function getName() external view returns(string memory);

    /// @notice Returns the total available funds during an `_epoch`
    function getTotalAvailableFunds(uint256 _epoch) external view returns(uint256);

    /// @notice Returns the payout per reservations during an `_epoch`
    function getPayoutPerReservation(uint256 _epoch) external view returns(uint256);

    /// @notice Returns the total amount of risk points outstanding in an `_epoch`
    function getRiskPoints(uint256 _epoch) external view returns(uint256);

    /// @notice Returns total amount of tokens purchased during an `_epoch`
    function getTokensPurchased(uint256 _epoch) external view returns(uint256);

    /// @notice Returns a users position information
    function getPosition(
        address _user, 
        uint256 _nonce
    ) external view returns(
        uint32 startEpoch,
        uint32 endEpoch,
        uint256 tickets, 
        uint256 amounts,
        uint256 ethLocked
    );

    /// @notice Get the list of NFT address and corresponding token IDs in by this pool
    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool);

    /// @notice Get the amount of spots in a ticket that have been purchased during an epoch
    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256);
}