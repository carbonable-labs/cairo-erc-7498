use starknet::ContractAddress;
use starknet::contract_address_const;
use snforge_std::{declare, ContractClassTrait};
use openzeppelin::introspection::interface::{ISRC5DispatcherTrait, ISRC5Dispatcher};
use cairo_erc_7498::erc7498::interface::{
    IERC7498_ID,
    ItemType,
    OfferItem,
    ConsiderationItem,
    CampaignRequirements,
    CampaignParams,
    IERC7498DispatcherTrait,
    IERC7498Dispatcher,
};

fn deploy_erc7498() -> ContractAddress {
    let contract = declare("ERC7498NFTRedeemables");
    contract.deploy(@ArrayTrait::new()).unwrap()
}

fn get_campaign_params() -> CampaignParams {
    CampaignParams {
        start_time: 0,
        end_time: 1000,
        max_campaign_redemptions: 10,
        manager: contract_address_const::<'ADMIN'>(),
        signer: contract_address_const::<'OTHER_ADMIN'>(),
        requirements: array![CampaignRequirements {
            offer: array![OfferItem {
                item_type: ItemType::ERC20,
                token: contract_address_const::<0>(),
                identifier_or_criteria: 0,
                start_amount: 1,
                end_amount: 10,
            }],
            consideration: array![]
        }],
    }
}

fn get_campaign_uri() -> ByteArray {
    "https://www.carbonable.io"
}

#[test]
fn supports_interface() {
    let contract_address = deploy_erc7498();
    let dispatcher = ISRC5Dispatcher { contract_address };
    assert!(dispatcher.supports_interface(IERC7498_ID));
}

#[test]
fn create_campaign() {
    let contract_address = deploy_erc7498();
    let dispatcher = IERC7498Dispatcher { contract_address };
    let sample_campaign_params = get_campaign_params();
    let campaign_id = dispatcher.create_campaign(sample_campaign_params.clone(), get_campaign_uri());
    assert_eq!(campaign_id, 1);
    let (campaign_params, campaign_uri, total_redemptions) = dispatcher.get_campaign(campaign_id);
    assert_eq!(campaign_params.start_time, sample_campaign_params.start_time);
    assert_eq!(campaign_params.end_time, sample_campaign_params.end_time);
    assert_eq!(campaign_params.max_campaign_redemptions, sample_campaign_params.max_campaign_redemptions);
    assert_eq!(campaign_params.manager, sample_campaign_params.manager);
    assert_eq!(campaign_params.signer, sample_campaign_params.signer);
    assert_eq!(campaign_uri, get_campaign_uri());
    assert_eq!(total_redemptions, 0);
}
