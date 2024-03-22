use starknet::ContractAddress;

const IERC7498_ID: felt252 = 0x1ac61e13;

const BURN_ADDRESS: felt252 = 0x00000000000000000000000000000000000000000000000000000000000dEaD;

#[derive(Clone, PartialEq, Drop, Serde, starknet::Store)]
enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,
    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,
    // 2: ERC721 items
    ERC721,
    // 3: ERC1155 items
    ERC1155,
    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,
    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

// @dev An offer item has five components: an item type (ETH or other native
//      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
//      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
//      component that will either represent a tokenId or a merkle root
//      depending on the item type, and a start and end amount that support
//      increasing or decreasing amounts over the duration of the respective
//      order.
#[derive(Clone, PartialEq, Drop, Serde, starknet::Store)]
struct OfferItem {
    item_type: ItemType,
    token: ContractAddress,
    identifier_or_criteria: u256,
    start_amount: u256,
    end_amount: u256,
}

// @dev A consideration item has the same five components as an offer item and
//      an additional sixth component designating the required recipient of the
//      item.
#[derive(Clone, PartialEq, Drop, Serde, starknet::Store)]
struct ConsiderationItem {
    item_type: ItemType,
    token: ContractAddress,
    identifier_or_criteria: u256,
    start_amount: u256,
    end_amount: u256,
    recipient: ContractAddress
}

#[derive(Clone, PartialEq, Drop, Serde)]
struct CampaignRequirements {
    offer: Array<OfferItem>,
    consideration: Array<ConsiderationItem>,
// trait_redemptions: Array<TraitRedemption>
}

#[derive(Drop, Serde, starknet::Store)]
struct CampaignRequirementsStorage {
    offer_len: u32,
    consideration_len: u32
}

#[derive(Clone, PartialEq, Drop, Serde)]
struct CampaignParams {
    start_time: u32,
    end_time: u32,
    max_campaign_redemptions: u32,
    manager: ContractAddress,
    signer: ContractAddress,
    requirements: Array<CampaignRequirements>
}

#[derive(Drop, Serde, starknet::Store)]
struct CampaignParamsStorage {
    start_time: u32,
    end_time: u32,
    max_campaign_redemptions: u32,
    manager: ContractAddress,
    signer: ContractAddress,
    requirements_len: u32,
}

#[starknet::interface]
trait IERC7498<TState> {
    fn get_campaign(self: @TState, campaign_id: u256) -> (CampaignParams, ByteArray, u256);
    fn create_campaign(ref self: TState, params: CampaignParams, uri: ByteArray) -> u256;
    fn update_campaign(
        ref self: TState, campaign_id: u256, params: CampaignParams, uri: ByteArray
    );
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
}
