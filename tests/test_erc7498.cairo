use core::panic_with_felt252;
use core::traits::TryInto;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::get_block_timestamp;
use snforge_std::{
    declare, ContractClassTrait, test_address, spy_events, SpyOn, EventSpy, EventAssertions
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::token::erc721::ERC721Component;
use cairo_erc_7498::erc7498::interface::{
    IERC7498_ID, BURN_ADDRESS, ItemType, OfferItem, ConsiderationItem, CampaignRequirements,
    CampaignParams,
};
use cairo_erc_7498::erc7498::erc7498::ERC7498Component;
use cairo_erc_7498::presets::erc721_redeemables::{
    ERC721Redeemables, IERC721RedeemablesMixinDispatcherTrait, IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcherTrait, IERC721RedeemablesMixinSafeDispatcher
};
use cairo_erc_7498::presets::erc721_redemption::{
    ERC721RedemptionMintable, IERC721RedemptionMintableMixinDispatcherTrait,
    IERC721RedemptionMintableMixinDispatcher, IERC721RedemptionMintableMixinSafeDispatcherTrait,
    IERC721RedemptionMintableMixinSafeDispatcher
};

const TOKEN_ID: u256 = 2;
const INVALID_TOKEN_ID: u256 = TOKEN_ID + 1;

fn NAME() -> ByteArray {
    "ERC721Redeemables"
}

fn SYMBOL() -> ByteArray {
    "ERC721RDM"
}

fn BASE_URI() -> ByteArray {
    "https://example.com"
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

fn CAMPAIGN_URI() -> ByteArray {
    "https://example.com/campaign"
}

fn setup() -> (
    ContractAddress,
    IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcher,
    ContractAddress,
    IERC721RedeemablesMixinDispatcher,
    IERC721RedeemablesMixinSafeDispatcher,
    ContractAddress,
    IERC721RedemptionMintableMixinDispatcher,
    IERC721RedemptionMintableMixinSafeDispatcher
) {
    let redeem_contract = declare("ERC721Redeemables");
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    let redeem_contract_address = redeem_contract.deploy(@calldata).unwrap();
    let redeem_token = IERC721RedeemablesMixinDispatcher {
        contract_address: redeem_contract_address
    };
    let redeem_token_safe = IERC721RedeemablesMixinSafeDispatcher {
        contract_address: redeem_contract_address
    };
    let second_redeem_contract_address = redeem_contract.deploy(@calldata).unwrap();
    let second_redeem_token = IERC721RedeemablesMixinDispatcher {
        contract_address: second_redeem_contract_address
    };
    let second_redeem_token_safe = IERC721RedeemablesMixinSafeDispatcher {
        contract_address: second_redeem_contract_address
    };
    let receive_contract = declare("ERC721RedemptionMintable");
    calldata.append_serde(redeem_contract_address);
    let receive_contract_address = receive_contract.deploy(@calldata).unwrap();
    let receive_token = IERC721RedemptionMintableMixinDispatcher {
        contract_address: receive_contract_address
    };
    let receive_token_safe = IERC721RedemptionMintableMixinSafeDispatcher {
        contract_address: receive_contract_address
    };
    (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        second_redeem_contract_address,
        second_redeem_token,
        second_redeem_token_safe,
        receive_contract_address,
        receive_token,
        receive_token_safe
    )
}

#[test]
fn supports_interface() {
    let (
        _redeem_contract_address,
        redeem_token,
        _redeem_token_safe,
        _second_redeem_contract_address,
        _second_redeem_token,
        _second_redeem_token_safe,
        _receive_contract_address,
        _receive_token,
        _receive_token_safe
    ) =
        setup();
    assert!(redeem_token.supports_interface(IERC7498_ID));
}

#[test]
fn test_burn_internal_token() {
    let (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        _second_redeem_contract_address,
        _second_redeem_token,
        _second_redeem_token_safe,
        receive_contract_address,
        receive_token,
        _receive_token_safe
    ) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);

    let offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let requirements = array![
        CampaignRequirements { offer: offer.span(), consideration: consideration.span() }
    ];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());

    // let offer_from_event = array![OfferItem {
    //     item_type: ItemType::ERC721,
    //     token: receive_contract_address,
    //     identifier_or_criteria: 0,
    //     start_amount: 1,
    //     end_amount: 1
    // }];
    // let consideration_from_event = array![ConsiderationItem {
    //     item_type: ItemType::ERC721,
    //     token: redeem_contract_address,
    //     identifier_or_criteria: 0,
    //     start_amount: 1,
    //     end_amount: 1,
    //     recipient: contract_address_const::<BURN_ADDRESS>()
    // }];

    // campaignId: 1
    // requirementsIndex: 0
    // redemptionHash: bytes32(0)
    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID];
    let trait_redemption_token_ids = array![];
    let mut spy = spy_events(SpyOn::One(redeem_contract_address));
    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());
    spy
        .assert_emitted(
            @array![
                (
                    redeem_contract_address,
                    ERC7498Component::Event::Redemption(
                        ERC7498Component::Redemption {
                            campaign_id: 1,
                            requirements_index: 0,
                            redemption_hash: 0,
                            consideration_token_ids: consideration_token_ids.span(),
                            trait_redemption_token_ids: trait_redemption_token_ids.span(),
                            redeemed_by: test_address()
                        }
                    )
                )
            ]
        );

    match redeem_token_safe.owner_of(TOKEN_ID) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }

    assert_eq!(receive_token.owner_of(1), test_address());
}

#[test]
fn test_revert_721_consideration_item_insufficient_balance() {
    let (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        _second_redeem_contract_address,
        _second_redeem_token,
        _second_redeem_token_safe,
        receive_contract_address,
        _receive_token,
        receive_token_safe
    ) =
        setup();
    redeem_token.mint(test_address(), TOKEN_ID);
    redeem_token.mint(RECIPIENT(), INVALID_TOKEN_ID);

    let offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let requirements = array![
        CampaignRequirements { offer: offer.span(), consideration: consideration.span() }
    ];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![INVALID_TOKEN_ID];
    match redeem_token_safe
        .redeem(consideration_token_ids.span(), test_address(), extra_data.span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(
                *panic_data.at(0), ERC7498Component::Errors::CONSIDERATION_ITEM_INSUFFICIENT_BALANCE
            );
        }
    }

    assert_eq!(redeem_token.owner_of(TOKEN_ID), test_address());

    match receive_token_safe.owner_of(1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
}

#[test]
fn test_revert_consideration_length_not_met() {
    let (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        second_redeem_contract_address,
        _second_redeem_token,
        _second_redeem_token_safe,
        receive_contract_address,
        _receive_token,
        receive_token_safe
    ) =
        setup();
    redeem_token.mint(test_address(), TOKEN_ID);

    let offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        },
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: second_redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let requirements = array![
        CampaignRequirements { offer: offer.span(), consideration: consideration.span() }
    ];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID];
    match redeem_token_safe
        .redeem(consideration_token_ids.span(), test_address(), extra_data.span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(
                *panic_data.at(0),
                ERC7498Component::Errors::TOKEN_IDS_DONT_MATCH_CONSIDERATION_LENGTH
            );
        }
    }

    assert_eq!(redeem_token.owner_of(TOKEN_ID), test_address());

    match receive_token_safe.owner_of(1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
}

#[test]
fn test_burn_with_second_consideration_item() {
    let (
        redeem_contract_address,
        redeem_token,
        redeem_token_safe,
        second_redeem_contract_address,
        second_redeem_token,
        second_redeem_token_safe,
        receive_contract_address,
        receive_token,
        _receive_token_safe
    ) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    second_redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);
    second_redeem_token.mint(test_address(), TOKEN_ID);

    let offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        },
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: second_redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let requirements = array![
        CampaignRequirements { offer: offer.span(), consideration: consideration.span() }
    ];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());

    let extra_data = array![1, 0, 0];
    let consideration_token_ids = array![TOKEN_ID, TOKEN_ID];
    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());

    match redeem_token_safe.owner_of(TOKEN_ID) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }

    match second_redeem_token_safe.owner_of(TOKEN_ID) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }

    assert_eq!(receive_token.owner_of(1), test_address());
}

#[test]
fn test_burn_with_second_requirements_index() {
    let (
        redeem_contract_address,
        redeem_token,
        _redeem_token_safe,
        second_redeem_contract_address,
        second_redeem_token,
        second_redeem_token_safe,
        receive_contract_address,
        receive_token,
        _receive_token_safe
    ) =
        setup();
    redeem_token.set_approval_for_all(redeem_contract_address, true);
    second_redeem_token.set_approval_for_all(redeem_contract_address, true);
    redeem_token.mint(test_address(), TOKEN_ID);
    second_redeem_token.mint(test_address(), TOKEN_ID);

    let offer = array![
        OfferItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: receive_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1
        }
    ];

    let consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let second_requirements_consideration = array![
        ConsiderationItem {
            item_type: ItemType::ERC721_WITH_CRITERIA,
            token: second_redeem_contract_address,
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
            recipient: BURN_ADDRESS()
        }
    ];

    let requirements = array![
        CampaignRequirements { offer: offer.span(), consideration: consideration.span() },
        CampaignRequirements {
            offer: offer.span(), consideration: second_requirements_consideration.span()
        }
    ];

    let timestamp: u32 = get_block_timestamp().try_into().unwrap();
    let params = CampaignParams {
        requirements: requirements.span(),
        signer: ZERO(),
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address()
    };

    redeem_token.create_campaign(params, CAMPAIGN_URI());

    let extra_data = array![1, 1, 0];
    let consideration_token_ids = array![TOKEN_ID];
    redeem_token.redeem(consideration_token_ids.span(), test_address(), extra_data.span());

    assert_eq!(redeem_token.owner_of(TOKEN_ID), test_address());

    match second_redeem_token_safe.owner_of(TOKEN_ID) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }

    assert_eq!(receive_token.owner_of(1), test_address());
}
