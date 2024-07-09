use starknet::{ContractAddress, contract_address_const};
use starknet::get_block_timestamp;
use snforge_std::{declare, ContractClassTrait, test_address, cheat_block_timestamp_global};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, BASE_URI, ZERO, TOKEN_ID};
use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin::token::erc721::interface::IERC721_ID;
use cairo_erc_7498::erc7498::redeemables_constants::BURN_ADDRESS;
use cairo_erc_7498::erc7498::redeemables_structs::{
    TraitRedemption, CampaignParams, CampaignRequirements, Campaign
};
use cairo_erc_7498::utils::consideration_enums::ItemType;
use cairo_erc_7498::utils::consideration_structs::{
    OfferItem, OfferItemTrait, ConsiderationItem, ConsiderationItemTrait
};
use cairo_erc_7498::presets::erc721_redeemable_mintable::{
    IERC721RedeemableMintableMixinDispatcher, IERC721RedeemableMintableMixinDispatcherTrait,
    IERC721RedeemableMintableMixinSafeDispatcher, IERC721RedeemableMintableMixinSafeDispatcherTrait
};
use snforge_std::start_cheat_caller_address;

#[test]
fn example(){
    let erc721_redeemable_contract = declare("ERC721RedeemableMintable").unwrap();
    //let mut erc721_redeemable_calldata = array!['erc721_type1', 'T1', 'http://type1.com'];
    let mut erc721_redeemable_calldata = array![];
        erc721_redeemable_calldata.append_serde(NAME());
        erc721_redeemable_calldata.append_serde(SYMBOL());
        erc721_redeemable_calldata.append_serde(BASE_URI());

    let (erc721_redeemable_contract_address, _) = erc721_redeemable_contract
            .deploy(@erc721_redeemable_calldata)
            .unwrap();

    let erc721_redeemable = IERC721RedeemableMintableMixinDispatcher {
        contract_address: erc721_redeemable_contract_address
    };

    erc721_redeemable.set_approval_for_all(erc721_redeemable_contract_address, true);

    let mut erc7498_tokens = array![];
    erc7498_tokens.append(erc721_redeemable_contract_address);

    let (receive_token721_contract_address, _) = erc721_redeemable_contract
        .deploy(@erc721_redeemable_calldata)
        .unwrap();
    let receive_token721 = IERC721RedeemableMintableMixinDispatcher {
        contract_address: erc721_redeemable_contract_address
    };

    let mut receive_tokens = array![];
    receive_tokens.append(receive_token721_contract_address);

    receive_token721.set_redeemables_contracts(erc7498_tokens.span());
    assert_eq!(receive_token721.get_redeemables_contracts(), erc7498_tokens.span());


    let single_erc721_offer = OfferItemTrait::empty().with_item_type(ItemType::ERC721).with_amount(1);

    let default_erc721_campaign_offer = single_erc721_offer
            .with_token(receive_token721_contract_address)
            .with_item_type(ItemType::ERC721_WITH_CRITERIA);
    let default_campaign_offer = array![default_erc721_campaign_offer];


    let single_erc721_consideration = ConsiderationItemTrait::empty().with_item_type(ItemType::ERC721).with_amount(1);
    
    let default_erc721_campaign_consideration = single_erc721_consideration
        .with_token(erc721_redeemable_contract_address)
        .with_recipient(BURN_ADDRESS())
        .with_item_type(ItemType::ERC721_WITH_CRITERIA)
        .with_amount(1);
    let default_campaign_consideration = array![default_erc721_campaign_consideration];

    let default_trait_redemptions = array![];


    let consideration = array![
        default_erc721_campaign_consideration.with_token(erc721_redeemable_contract_address).with_item_type(ItemType::ERC721_WITH_CRITERIA),
    ];
    
    let requirements = array![
        CampaignRequirements {
            offer: default_campaign_offer.span(),
            consideration: default_campaign_consideration.span(),
            trait_redemptions: default_trait_redemptions.span(),
        }
    ];

    let timestamp = get_block_timestamp();
    let params = CampaignParams {
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address(),
        signer: ZERO(),
    };

    let mut campaign = Campaign { params, requirements: requirements.span() };
    let campaign_id = erc721_redeemable.create_campaign(campaign, "campaingTest1");


    let user1: ContractAddress = contract_address_const::<1234>();
    let user2: ContractAddress = contract_address_const::<567>();

    erc721_redeemable.mint(user1, TOKEN_ID + 1);
    erc721_redeemable.mint(user1, TOKEN_ID + 2);
    erc721_redeemable.mint(user2, TOKEN_ID + 3);

    //erc721_redeemable.mint(user1, TOKEN_ID + 4);

    let mut extra_data = array![];
    extra_data.append_serde(campaign_id);
    extra_data.append_serde(0);
    extra_data.append_serde(0);

    let consideration_token_ids = array![TOKEN_ID+3];

    //assert_eq!(erc721_redeemable.owner_of(TOKEN_ID+3), user2);

    start_cheat_caller_address(erc721_redeemable_contract_address, user2);
    erc721_redeemable.redeem(consideration_token_ids.span(), user2, extra_data.span());

}