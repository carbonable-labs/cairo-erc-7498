use starknet::ContractAddress;
use cairo_erc_7498::erc7498::interface::CampaignParams;

#[starknet::interface]
pub trait IERC721Redeemables<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
    fn burn(ref self: TState, token_id: u256);
    fn create_campaign(ref self: TState, params: CampaignParams, uri: ByteArray) -> u256;
}

#[starknet::interface]
pub trait IERC721RedeemablesMixin<TState> {
    // IERC721Redeemables
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
    // IERC721Burnable
    fn burn(ref self: TState, token_id: u256);
    // IERC7498
    fn get_campaign(self: @TState, campaign_id: u256) -> (CampaignParams, ByteArray, u256);
    fn create_campaign(ref self: TState, params: CampaignParams, uri: ByteArray) -> u256;
    fn update_campaign(ref self: TState, campaign_id: u256, params: CampaignParams, uri: ByteArray);
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
    // IERC721
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    // Ownable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::contract]
pub mod ERC721Redeemables {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use cairo_erc_7498::erc7498::erc7498::ERC7498Component;
    use cairo_erc_7498::erc7498::interface::CampaignParams;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC7498Component, storage: erc7498, event: ERC7498Event);

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC7498
    #[abi(embed_v0)]
    impl ERC7498Impl = ERC7498Component::ERC7498Impl<ContractState>;
    impl ERC7498InternalImpl = ERC7498Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc7498: ERC7498Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC7498Event: ERC7498Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray
    ) {
        self.ownable.initializer(get_caller_address());
        self.erc721.initializer(name, symbol, base_uri);
        self.erc7498.initializer();
    }

    #[abi(embed_v0)]
    impl ERC721RedeemablesImpl of super::IERC721Redeemables<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.ownable.assert_only_owner();
            self.erc721._mint(to, token_id);
        }

        fn burn(ref self: ContractState, token_id: u256) {
            assert(
                self.erc721._is_approved_or_owner(get_caller_address(), token_id),
                ERC721Component::Errors::UNAUTHORIZED
            );
            self.erc721._burn(token_id);
        }

        fn create_campaign(
            ref self: ContractState, params: CampaignParams, uri: ByteArray
        ) -> u256 {
            self.ownable.assert_only_owner();
            self.erc7498._create_campaign(@params, uri)
        }
    }
}
