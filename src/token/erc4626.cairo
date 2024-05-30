mod erc4626;

#[starknet::contract]

mod ERC4626Contract {
    use erc4626::ERC4626Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;

    component!(path: ERC4626Component, storage: erc4626, event: ERC4626Event);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{get_contract_address, ContractAddress};

    #[abi(embed_v0)]
    impl ERC4626Impl = ERC4626Component::ERC4626AdditionalImpl<ContractState>;
    #[abi(embed_v0)]
    impl MetadataEntrypointsImpl = ERC4626Component::MetadataEntrypointsImpl<ContractState>;
    #[abi(embed_v0)]
    impl SnakeEntrypointsImpl = ERC4626Component::SnakeEntrypointsImpl<ContractState>;
    #[abi(embed_v0)]
    impl CamelEntrypointsImpl = ERC4626Component::CamelEntrypointsImpl<ContractState>;

    impl ERC4626InternalImpl = ERC4626Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc4626: ERC4626Component::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC4626Event: ERC4626Component::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        asset: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        offset: u8,
    ) {
        self.erc4626.initializer(asset, name, symbol, offset);
    }
}