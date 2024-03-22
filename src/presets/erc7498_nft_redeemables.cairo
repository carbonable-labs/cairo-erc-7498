#[starknet::contract]
mod ERC7498NFTRedeemables {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait;
    use cairo_erc_7498::erc7498::erc7498::ERC7498Component;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC7498Component, storage: erc7498, event: erc7498Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC7498
    #[abi(embed_v0)]
    impl ERC7498Impl = ERC7498Component::ERC7498Impl<ContractState>;
    impl ERC7498InternalImpl = ERC7498Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc7498: ERC7498Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        erc7498Event: ERC7498Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc7498.initializer();
    }
}
