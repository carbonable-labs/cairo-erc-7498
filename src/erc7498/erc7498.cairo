//! Component implementing IERC7498.

#[starknet::component]
pub mod ERC7498Component {
    use core::traits::TryInto;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::contract_address_const;
    use starknet::get_block_timestamp;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::dual20::DualCaseERC20Trait;
    use openzeppelin::token::erc20::dual20::DualCaseERC20;
    use openzeppelin::token::erc1155::dual1155::DualCaseERC1155Trait;
    use openzeppelin::token::erc1155::dual1155::DualCaseERC1155;
    use openzeppelin::token::erc721::dual721::DualCaseERC721Trait;
    use openzeppelin::token::erc721::dual721::DualCaseERC721;
    use cairo_erc_7498::erc7498::interface::{
        IERC7498, IERC7498_ID, BURN_ADDRESS, CampaignParams, CampaignParamsStorage,
        CampaignRequirements, CampaignRequirementsStorage, ItemType, OfferItem, ConsiderationItem,
        IRedemptionMintableDispatcher, IRedemptionMintableDispatcherTrait,
        IERC721BurnableDispatcher, IERC721BurnableDispatcherTrait, IERC1155BurnableDispatcher,
        IERC1155BurnableDispatcherTrait, IERC20BurnableDispatcher, IERC20BurnableDispatcherTrait
    };

    #[storage]
    struct Storage {
        /// @dev Counter for next campaign id.
        ERC7498_next_campaign_id: u256,
        /// @dev The campaign parameters by campaign id.
        ERC7498_campaign_params: LegacyMap<u256, CampaignParamsStorage>,
        ERC7498_requirements: LegacyMap<(u256, u32), CampaignRequirementsStorage>,
        ERC7498_offer: LegacyMap<(u256, u32, u32), OfferItem>,
        ERC7498_consideration: LegacyMap<(u256, u32, u32), ConsiderationItem>,
        /// @dev The campaign URIs by campaign id.
        ERC7498_campaign_uris: LegacyMap<u256, ByteArray>,
        /// @dev The total current redemptions by campaign id.
        ERC7498_total_redemptions: LegacyMap<u256, u256>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        CampaignUpdated: CampaignUpdated,
        Redemption: Redemption
    }

    /// Emitted when `campaign_id` campaign is updated.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CampaignUpdated {
        #[key]
        pub campaign_id: u256,
        pub params: CampaignParams,
        pub uri: ByteArray
    }

    /// Emitted when a redemption happens for `campaign_id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Redemption {
        #[key]
        pub campaign_id: u256,
        pub requirements_index: u256,
        pub redemption_hash: felt252,
        pub consideration_token_ids: Span<u256>,
        pub trait_redemption_token_ids: Span<u256>,
        pub redeemed_by: ContractAddress
    }

    pub mod Errors {
        /// Configuration errors
        pub const NOT_MANAGER: felt252 = 'ERC7498: not manager';
        pub const INVALID_TIME: felt252 = 'ERC7498: invalid time';
        pub const CONSIDERATION_ITEM_RECIPIENT_CANNOT_BE_ZERO_ADDRESS: felt252 =
            'ERC7498: CIR cannot be 0';
        pub const CONSIDERATION_ITEM_AMOUNT_CANNOT_BE_ZERO: felt252 = 'ERC7498: CIA cannot be 0';
        pub const NON_MATCHING_CONSIDERATION_ITEM_AMOUNTS: felt252 = 'ERC7498: non matching CIA';
        /// Redemption errors
        pub const INVALID_CAMPAIGN_ID: felt252 = 'ERC7498: invalid campaign id';
        pub const NOT_ACTIVE: felt252 = 'ERC7498: not active';
        pub const MAX_CAMPAIGN_REDEMPTIONS_REACHED: felt252 = 'ERC7498: max redemptions reach';
        pub const REQUIREMENTS_INDEX_OUT_OF_BOUNDS: felt252 = 'ERC7498: requirements index OOB';
        pub const CONSIDERATION_ITEM_INSUFFICIENT_BALANCE: felt252 = 'ERC7498: CI insufficient bal';
        pub const INVALID_CONSIDERATION_TOKEN_ID_SUPPLIED: felt252 = 'ERC7498: invalid CTI';
        pub const TOKEN_IDS_DONT_MATCH_CONSIDERATION_LENGTH: felt252 =
            'ERC7498: token ids mismatch';
    }

    //
    // External
    //

    #[embeddable_as(ERC7498Impl)]
    impl ERC7498<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC7498<ComponentState<TContractState>> {
        fn get_campaign(
            self: @ComponentState<TContractState>, campaign_id: u256
        ) -> (CampaignParams, ByteArray, u256) {
            // Revert if campaign id is invalid.
            assert(campaign_id < self.ERC7498_next_campaign_id.read(), Errors::INVALID_CAMPAIGN_ID);
            (
                // Get the campaign params.
                self._read_campaign_params(campaign_id),
                // Get the campaign URI.
                self.ERC7498_campaign_uris.read(campaign_id),
                // Get the total redemptions.
                self.ERC7498_total_redemptions.read(campaign_id)
            )
        }

        fn update_campaign(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            params: CampaignParams,
            uri: ByteArray
        ) {
            // Revert if the campaign id is invalid.
            assert(
                campaign_id != 0 && campaign_id < self.ERC7498_next_campaign_id.read(),
                Errors::INVALID_CAMPAIGN_ID
            );
            // Revert if msg.sender is not the manager.
            let existing_params = self._read_campaign_params(campaign_id);
            if params.manager != get_caller_address() {
                assert(
                    existing_params.manager == contract_address_const::<0>()
                        || existing_params.manager == params.manager,
                    Errors::NOT_MANAGER
                );
            }
            // Validate the campaign params and revert if invalid.
            self._validate_campaign_params(@params);
            // Set the campaign params.
            self._write_campaign_params(campaign_id, @params);
            // Update the campaign uri if it was provided.
            if (uri.len() != 0) {
                self.ERC7498_campaign_uris.write(campaign_id, uri.clone());
            }
            self.emit(CampaignUpdated { campaign_id, params: params.clone(), uri });
        }

        fn redeem(
            ref self: ComponentState<TContractState>,
            consideration_token_ids: Span<u256>,
            recipient: ContractAddress,
            extra_data: Span<felt252>
        ) {
            // Get the campaign id and requirementsIndex from extraData.
            let campaign_id: u256 = (*extra_data.at(0)).try_into().unwrap();
            let requirements_index: u256 = (*extra_data.at(1)).try_into().unwrap();
            // Get the campaign params.
            let params = self._read_campaign_params(campaign_id);
            // Validate the campaign time and total redemptions.
            self._validate_redemption(campaign_id, @params);
            // Increment totalRedemptions.
            let total_redemptions = self.ERC7498_total_redemptions.read(campaign_id);
            self.ERC7498_total_redemptions.write(campaign_id, total_redemptions + 1);
            // Get the campaign requirements.
            assert(
                requirements_index < params.requirements.len().into(),
                Errors::REQUIREMENTS_INDEX_OUT_OF_BOUNDS
            );
            // Process the redemption.
            self
                ._process_redemption(
                    campaign_id,
                    requirements_index.try_into().unwrap(),
                    consideration_token_ids,
                    recipient
                );
            // TODO: decode traitRedemptionTokenIds from extraData.
            let trait_redemption_token_ids = array![];
            // Emit the Redemption event.
            self
                .emit(
                    Redemption {
                        campaign_id,
                        requirements_index,
                        redemption_hash: 0,
                        consideration_token_ids,
                        trait_redemption_token_ids: trait_redemption_token_ids.span(),
                        redeemed_by: get_caller_address()
                    }
                );
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting next campaign id
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            self.ERC7498_next_campaign_id.write(1);
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC7498_ID);
        }

        fn _create_campaign(
            ref self: ComponentState<TContractState>, params: @CampaignParams, uri: ByteArray
        ) -> u256 {
            // Validate the campaign params, reverts if invalid.
            self._validate_campaign_params(params);
            // Set the campaignId and increment the next one.
            let campaign_id = self.ERC7498_next_campaign_id.read();
            self.ERC7498_next_campaign_id.write(campaign_id + 1);
            // Set the campaign params.
            self._write_campaign_params(campaign_id, params);
            // Set the campaign URI.
            self.ERC7498_campaign_uris.write(campaign_id, uri.clone());
            self.emit(CampaignUpdated { campaign_id, params: params.clone(), uri });
            campaign_id
        }

        fn _read_offer(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            offer_len: u32
        ) -> Span<OfferItem> {
            let mut offer = array![];
            let mut offer_counter = 0;
            while offer_counter < offer_len {
                let offer_item = self
                    .ERC7498_offer
                    .read((campaign_id, requirements_index, offer_counter));
                offer.append(offer_item);
                offer_counter += 1;
            };
            offer.span()
        }

        fn _read_consideration(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            consideration_len: u32
        ) -> Span<ConsiderationItem> {
            let mut consideration = array![];
            let mut consideration_counter = 0;
            while consideration_counter < consideration_len {
                let consideration_item = self
                    .ERC7498_consideration
                    .read((campaign_id, requirements_index, consideration_counter));
                consideration.append(consideration_item);
                consideration_counter += 1;
            };
            consideration.span()
        }

        fn _read_requirements(
            self: @ComponentState<TContractState>, campaign_id: u256, requirements_len: u32
        ) -> Span<CampaignRequirements> {
            let mut requirements = array![];
            let mut requirements_counter = 0;
            while requirements_counter < requirements_len {
                let requirement: CampaignRequirementsStorage = self
                    .ERC7498_requirements
                    .read((campaign_id, requirements_counter));
                requirements
                    .append(
                        CampaignRequirements {
                            offer: self
                                ._read_offer(
                                    campaign_id, requirements_counter, requirement.offer_len
                                ),
                            consideration: self
                                ._read_consideration(
                                    campaign_id, requirements_counter, requirement.consideration_len
                                )
                        }
                    );
                requirements_counter += 1;
            };
            requirements.span()
        }

        fn _read_campaign_params(
            self: @ComponentState<TContractState>, campaign_id: u256
        ) -> CampaignParams {
            let params: CampaignParamsStorage = self.ERC7498_campaign_params.read(campaign_id);
            CampaignParams {
                start_time: params.start_time,
                end_time: params.end_time,
                max_campaign_redemptions: params.max_campaign_redemptions,
                manager: params.manager,
                signer: params.signer,
                requirements: self._read_requirements(campaign_id, params.requirements_len),
            }
        }

        fn _write_offer(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_counter: u32,
            offer: Span<OfferItem>
        ) {
            let mut offer_counter = 0;
            while offer_counter < offer
                .len() {
                    let offer_item = *offer[offer_counter];
                    self
                        .ERC7498_offer
                        .write((campaign_id, requirements_counter, offer_counter), offer_item);
                    offer_counter += 1;
                };
        }

        fn _write_consideration(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_counter: u32,
            consideration: Span<ConsiderationItem>
        ) {
            let mut consideration_counter = 0;
            while consideration_counter < consideration
                .len() {
                    let consideration_item = *consideration[consideration_counter];
                    self
                        .ERC7498_consideration
                        .write(
                            (campaign_id, requirements_counter, consideration_counter),
                            consideration_item
                        );
                    consideration_counter += 1;
                };
        }

        fn _write_requirements(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements: Span<CampaignRequirements>
        ) {
            let mut requirements_counter = 0;
            while requirements_counter < requirements
                .len() {
                    let requirement = *requirements[requirements_counter];
                    self
                        .ERC7498_requirements
                        .write(
                            (campaign_id, requirements_counter),
                            CampaignRequirementsStorage {
                                offer_len: requirement.offer.len(),
                                consideration_len: requirement.consideration.len(),
                            }
                        );
                    self._write_offer(campaign_id, requirements_counter, requirement.offer);
                    self
                        ._write_consideration(
                            campaign_id, requirements_counter, requirement.consideration
                        );
                    requirements_counter += 1;
                };
        }

        fn _write_campaign_params(
            ref self: ComponentState<TContractState>, campaign_id: u256, params: @CampaignParams
        ) {
            let requirements = *params.requirements;
            self
                .ERC7498_campaign_params
                .write(
                    campaign_id,
                    CampaignParamsStorage {
                        start_time: *params.start_time,
                        end_time: *params.end_time,
                        max_campaign_redemptions: *params.max_campaign_redemptions,
                        manager: *params.manager,
                        signer: *params.signer,
                        requirements_len: requirements.len(),
                    }
                );
            self._write_requirements(campaign_id, requirements);
        }

        fn _validate_campaign_params(
            self: @ComponentState<TContractState>, params: @CampaignParams
        ) {
            // Revert if startTime is past endTime.
            assert(*params.start_time < *params.end_time, Errors::INVALID_TIME);
            // Iterate over the requirements.
            let mut requirements_counter = 0;
            let requirements = *params.requirements;
            while requirements_counter < requirements
                .len() {
                    let requirement: CampaignRequirements = *requirements[requirements_counter];
                    let mut consideration_counter: u32 = 0;
                    // Validate each consideration item.
                    while consideration_counter < requirement
                        .consideration
                        .len() {
                            let consideration: ConsiderationItem = *requirement
                                .consideration[consideration_counter];
                            // Revert if any of the consideration item recipients is the zero address.
                            // 0xdead address should be used instead.
                            // For internal burn, override _internalBurn and set _useInternalBurn to true.
                            assert(
                                consideration.recipient != contract_address_const::<0>(),
                                Errors::CONSIDERATION_ITEM_RECIPIENT_CANNOT_BE_ZERO_ADDRESS
                            );
                            assert(
                                consideration.start_amount != 0,
                                Errors::CONSIDERATION_ITEM_AMOUNT_CANNOT_BE_ZERO
                            );
                            // Revert if startAmount != endAmount, as this requires more complex logic.
                            assert(
                                consideration.start_amount == consideration.end_amount,
                                Errors::NON_MATCHING_CONSIDERATION_ITEM_AMOUNTS
                            );
                            consideration_counter += 1;
                        };
                    requirements_counter += 1;
                };
        }

        fn _validate_redemption(
            ref self: ComponentState<TContractState>, campaign_id: u256, params: @CampaignParams
        ) {
            let start_time: u256 = (*params.start_time).into();
            let end_time: u256 = (*params.end_time).into();
            assert(!self._is_inactive(start_time, end_time), Errors::NOT_ACTIVE);
            let total_redemptions = self.ERC7498_total_redemptions.read(campaign_id);
            let max_campaign_redemptions = (*params.max_campaign_redemptions).into();
            assert(
                total_redemptions + 1 <= max_campaign_redemptions,
                Errors::MAX_CAMPAIGN_REDEMPTIONS_REACHED
            );
        }

        fn _is_inactive(
            self: @ComponentState<TContractState>, start_time: u256, end_time: u256
        ) -> bool {
            let timestamp: u256 = get_block_timestamp().into();
            timestamp < start_time || timestamp > end_time
        }

        fn _process_redemption(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            consideration_token_ids: Span<u256>,
            recipient: ContractAddress
        ) {
            let requirement = self.ERC7498_requirements.read((campaign_id, requirements_index));
            // Get the campaign consideration.
            let consideration = self
                ._read_consideration(
                    campaign_id, requirements_index, requirement.consideration_len
                );
            // Revert if the tokenIds length does not match the consideration length.
            assert(
                consideration.len() == consideration_token_ids.len(),
                Errors::TOKEN_IDS_DONT_MATCH_CONSIDERATION_LENGTH
            );
            // Iterate over the consideration items.
            let mut consideration_counter = 0;
            while consideration_counter < requirement
                .consideration_len {
                    // Get the consideration item.
                    let consideration_item: ConsiderationItem =
                        *consideration[consideration_counter];
                    // Get the identifier.
                    let id = *consideration_token_ids[consideration_counter];
                    // Get the token balance.
                    let mut balance: u256 = 0;
                    match consideration_item.item_type {
                        ItemType::ERC721 |
                        ItemType::ERC721_WITH_CRITERIA => {
                            let token = DualCaseERC721 {
                                contract_address: consideration_item.token
                            };
                            balance =
                                if token.owner_of(id) == get_caller_address() {
                                    1
                                } else {
                                    0
                                };
                        },
                        ItemType::ERC1155 |
                        ItemType::ERC1155_WITH_CRITERIA => {
                            let token = DualCaseERC1155 {
                                contract_address: consideration_item.token
                            };
                            balance = token.balance_of(get_caller_address(), id);
                        },
                        ItemType::ERC20 => {
                            let token = DualCaseERC20 {
                                contract_address: consideration_item.token
                            };
                            balance = token.balance_of(get_caller_address());
                        }
                    };
                    // Ensure the balance is sufficient.
                    assert(
                        balance >= consideration_item.start_amount,
                        Errors::CONSIDERATION_ITEM_INSUFFICIENT_BALANCE
                    );
                    // Transfer the consideration item.
                    self._transfer_consideration_item(id, consideration_item);
                    // Get the campaign offer.
                    let offer = self
                        ._read_offer(campaign_id, requirements_index, requirement.offer_len);
                    // Mint the new tokens.
                    let mut offer_counter = 0;
                    while offer_counter < requirement
                        .offer_len {
                            let offer_item: OfferItem = *offer[offer_counter];
                            let redemption = IRedemptionMintableDispatcher {
                                contract_address: offer_item.token
                            };
                            redemption
                                .mint_redemption(campaign_id, recipient, offer_item, consideration);
                            offer_counter += 1;
                        };
                    consideration_counter += 1;
                }
        // TODO
        // Process trait redemptions.
        // TraitRedemption[] memory traitRedemptions = requirements.traitRedemptions;
        // _setTraits(traitRedemptions);
        }

        fn _transfer_consideration_item(
            ref self: ComponentState<TContractState>,
            id: u256,
            consideration_item: ConsiderationItem
        ) {
            // WITH_CRITERIA with identifier 0 is wildcard: any id is valid.
            // Criteria is not yet implemented, for that functionality use the contract offerer.
            if id != consideration_item.identifier_or_criteria
                && consideration_item.identifier_or_criteria != 0 {
                assert(
                    consideration_item.item_type == ItemType::ERC721_WITH_CRITERIA
                        && consideration_item.item_type == ItemType::ERC1155_WITH_CRITERIA,
                    Errors::INVALID_CONSIDERATION_TOKEN_ID_SUPPLIED
                );
            }
            // Transfer the token to the consideration recipient.
            match consideration_item.item_type {
                ItemType::ERC721 |
                ItemType::ERC721_WITH_CRITERIA => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC721BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(id);
                    } else {
                        let token = DualCaseERC721 { contract_address: consideration_item.token };
                        token
                            .safe_transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                id,
                                array![].span()
                            );
                    }
                },
                ItemType::ERC1155 |
                ItemType::ERC1155_WITH_CRITERIA => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC1155BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(get_caller_address(), id, consideration_item.start_amount);
                    } else {
                        let token = DualCaseERC1155 { contract_address: consideration_item.token };
                        token
                            .safe_transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                id,
                                consideration_item.start_amount,
                                array![].span()
                            );
                    }
                },
                ItemType::ERC20 => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC20BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(get_caller_address(), consideration_item.start_amount);
                    } else {
                        let token = DualCaseERC20 { contract_address: consideration_item.token };
                        token
                            .transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                consideration_item.start_amount
                            );
                    }
                }
            };
        }
    }
}
