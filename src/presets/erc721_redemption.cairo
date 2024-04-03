use starknet::ContractAddress;
use cairo_erc_7498::erc7498::interface::{OfferItem, ConsiderationItem};

#[starknet::interface]
pub trait IERC721RedemptionMintable<TState> {
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
pub trait IERC721RedemptionMintableMixin<TState> {
    // IRedemptionMintable
    fn mint_redemption(
        ref self: TState,
        campaign_id: u256,
        recipient: ContractAddress,
        offer: OfferItem,
        consideration: Span<ConsiderationItem>,
    // trait_redemptions: Span<TraitRedemption>
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
pub mod ERC721RedemptionMintable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use cairo_erc_7498::erc7498::interface::{OfferItem, ConsiderationItem};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        /// @dev The next token id to mint.
        next_token_id: u256,
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        owner: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl ERC721RedemptionMintableImpl of super::IERC721RedemptionMintable<ContractState> {
        fn mint_redemption(
            ref self: ContractState,
            campaign_id: u256,
            recipient: ContractAddress,
            offer: OfferItem,
            consideration: Span<ConsiderationItem>,
        ) {
            // Require that msg.sender is valid.
            self.ownable.assert_only_owner();
            // Increment nextTokenId first so more of the same token id cannot be minted through reentrancy.
            let next_token_id = self.next_token_id.read();
            self.next_token_id.write(next_token_id + 1);
            self.erc721._mint(recipient, next_token_id);
        }
    }
}
