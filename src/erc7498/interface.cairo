use starknet::ContractAddress;
use starknet::contract_address_const;

pub const IERC7498_ID: felt252 = 0x1ac61e13;

pub fn BURN_ADDRESS() -> ContractAddress {
    contract_address_const::<0xdEaD>()
}

#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub enum ItemType {
    // 0: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,
    // 1: ERC721 items
    ERC721,
    // 2: ERC1155 items
    ERC1155,
    // 3: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,
    // 4: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

// @dev An offer item has five components: an item type (ETH or other native
//      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
//      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
//      component that will either represent a tokenId or a merkle root
//      depending on the item type, and a start and end amount that support
//      increasing or decreasing amounts over the duration of the respective
//      order.
#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct OfferItem {
    pub item_type: ItemType,
    pub token: ContractAddress,
    pub identifier_or_criteria: u256,
    pub start_amount: u256,
    pub end_amount: u256,
}

// @dev A consideration item has the same five components as an offer item and
//      an additional sixth component designating the required recipient of the
//      item.
#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct ConsiderationItem {
    pub item_type: ItemType,
    pub token: ContractAddress,
    pub identifier_or_criteria: u256,
    pub start_amount: u256,
    pub end_amount: u256,
    pub recipient: ContractAddress
}

#[derive(Copy, PartialEq, Drop, Serde)]
pub struct CampaignRequirements {
    pub offer: Span<OfferItem>,
    pub consideration: Span<ConsiderationItem>,
// trait_redemptions: Array<TraitRedemption>
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CampaignRequirementsStorage {
    pub offer_len: u32,
    pub consideration_len: u32
}

#[derive(Copy, PartialEq, Drop, Serde)]
pub struct CampaignParams {
    pub start_time: u32,
    pub end_time: u32,
    pub max_campaign_redemptions: u32,
    pub manager: ContractAddress,
    pub signer: ContractAddress,
    pub requirements: Span<CampaignRequirements>
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CampaignParamsStorage {
    pub start_time: u32,
    pub end_time: u32,
    pub max_campaign_redemptions: u32,
    pub manager: ContractAddress,
    pub signer: ContractAddress,
    pub requirements_len: u32,
}

#[starknet::interface]
pub trait IERC7498<TState> {
    fn get_campaign(self: @TState, campaign_id: u256) -> (CampaignParams, ByteArray, u256);
    // fn create_campaign(ref self: TState, params: CampaignParams, uri: ByteArray) -> u256;
    fn update_campaign(ref self: TState, campaign_id: u256, params: CampaignParams, uri: ByteArray);
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
}

pub const IREDEMPTION_MINTABLE_ID: felt252 = 0x81fe13c2;

#[starknet::interface]
pub trait IRedemptionMintable<TState> {
    fn mint_redemption(
        ref self: TState,
        campaign_id: u256,
        recipient: ContractAddress,
        offer: OfferItem,
        consideration: Span<ConsiderationItem>,
    // trait_redemptions: Span<TraitRedemption>
    );
}

#[starknet::interface]
pub trait IERC721Burnable<TState> {
    fn burn(ref self: TState, token_id: u256);
}

#[starknet::interface]
pub trait IERC1155Burnable<TState> {
    fn burn(ref self: TState, from: ContractAddress, token_id: u256, value: u256);
}

#[starknet::interface]
pub trait IERC20Burnable<TState> {
    fn burn(ref self: TState, account: ContractAddress, amount: u256);
}
