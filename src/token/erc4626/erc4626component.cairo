use starknet::ContractAddress;

#[starknet::component]
mod ERC4626Component {
    use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin::introspection::src5::{SRC5Component, SRC5Component::SRC5, SRC5Component::InternalTrait as SRC5INternalTrait};
    use openzeppelin::token::erc20::interface::{
        IERC20, IERC20Metadata, ERC20ABIDispatcher, ERC20ABIDispatcherTrait,
    };
    use openzeppelin::token::erc20::{
        ERC20Component, ERC20HooksEmptyImpl, ERC20Component::Errors as ERC20Errors
    };
    use integer::BoundedU256;
    use openzeppelin::token::erc20::ERC20Component::InternalTrait as ERC20InternalTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use hashstack_contracts::token::erc4626::IERC4626::{IERC4626, IERC4626Camel, IERC4626Metadata};

    // use hashstack_contracts::IERC4626::{IERC4626, IERC4626Camel, IERC4626Metadata};

    #[storage]
    struct Storage {
        ERC4626_asset: ContractAddress,
        ERC4626_underlying_decimals: u8,
        ERC4626_offset: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        sender: ContractAddress,
        #[key]
        owner: ContractAddress,
        assets: u256,
        shares: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        sender: ContractAddress,
        #[key]
        receiver: ContractAddress,
        #[key]
        owner: ContractAddress,
        assets: u256,
        shares: u256
    }

    mod Errors {
        const EXCEEDED_MAX_DEPOSIT: felt252 = 'ERC4626: exceeded max deposit';
        const EXCEEDED_MAX_MINT: felt252 = 'ERC4626: exceeded max mint';
        const EXCEEDED_MAX_REDEEM: felt252 = 'ERC4626: exceeded max redeem';
        const EXCEEDED_MAX_WITHDRAW: felt252 = 'ERC4626: exceeded max withdraw';
    }

    trait ERC4626HooksTrait<TContractState> {
        fn before_deposit(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256
        );
        fn after_deposit(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256
        );

        fn before_withdraw(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256
        );

        fn after_withdraw(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256
        );
    }

    #[embeddable_as(ERC4626Impl)]
    impl ERC4626<
        TContractState,
        +HasComponent<TContractState>,
        impl erc20: ERC20Component::HasComponent<TContractState>,
        +ERC4626HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC4626<ComponentState<TContractState>> {
        /// @notice Returns name of erc20 token ( STRK token )
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.name()
        }
        /// @notice Returns symbol of erc20 token ( STRK token )
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.symbol()
        }
        /// @notice Returns number decimals to keep count after decimal point 
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.ERC4626_underlying_decimals.read() + self.ERC4626_offset.read()
        }

        /// @notice Returns the total supply of STRK tokens in circulation
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.total_supply()
        }

        /// @notice Returns the balance of STRK tokens of user
        /// @param account Address of contract/account to calculate balance of STRK
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.balance_of(account)
        }

        /// @notice allows an address to spend STRK tokens on behalf of the user
        /// @param owner Address of user whose STRK tokens are to be spent
        /// @param spender Address of spender who will spend the STRK tokens
        /// @dev add return
        /// @return  
        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.allowance(owner, spender)
        }

        /// @notice transfer certain amount of tokens to a recipient address
        /// @param recipient Address where tokens get transferred
        /// @param amount Amount of tokens to get transferred 
        /// @return bool value whether transfer was successful 
        fn transfer(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) -> bool {
            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            erc20_comp_mut.transfer(recipient, amount)
        }

        /// @notice transfer certain amount of tokens form sender address to a recipient address
        /// @param sender Address which sends the tokens
        /// @param recipient Address where tokens get transferred
        /// @param amount Amount of tokens to get transferred 
        /// @return bool value whether transfer was successful 
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            erc20_comp_mut.transfer_from(sender, recipient, amount)
        }

        /// @notice approves a certain amount of tokens for an address to spend on behalf of the owner
        /// @param spender Address which spends the tokens
        /// @param amount Amount of tokens approved to spender 
        /// @return bool value whether approval was successful 
        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, amount: u256
        ) -> bool {
            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            erc20_comp_mut.approve(spender, amount)
        }

        /// @notice Returns the current ERC4626 asset of the calling contract
        /// @return ERC4626_asset value for the calling contract 
        fn asset(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ERC4626_asset.read()
        }

        /// @notice Stake STRK to Vault and mints liquid staking token 'hSTRK'
        /// @param shares Amount of htokens to convert 
        /// @return Returns amount of assets for particular amount of shares 
        fn convert_to_assets(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        /// @notice Stake STRK to Vault and mints liquid staking token 'hSTRK'
        /// @param assets Amount of token to convert
        /// @return Returns amount of shares for particular amount of assets   
        fn convert_to_shares(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        /// @notice Deposits the amount of assets to the vault
        /// @param assets Amount of token deposited to vault
        /// @param reciever Address where the amount of shares is to be minted
        /// @return Returns amount of minted shares
        fn deposit(
            ref self: ComponentState<TContractState>, assets: u256, receiver: ContractAddress
        ) -> u256 {
            let caller = get_caller_address();
            let shares = self.preview_deposit(assets);
            self._deposit(caller, receiver, assets, shares);
            shares
        }

        /// @notice Mint amount of hSTRK to user
        /// @param shares Amount of hSTRK the user intends to mint
        /// @param reciever Address where the amount of shares is to be minted
        /// @return Returns amount of assets required to mint given shares
        fn mint(
            ref self: ComponentState<TContractState>, shares: u256, receiver: ContractAddress
        ) -> u256 {
            let caller = get_caller_address();
            let assets = self.preview_mint(shares);
            self._deposit(caller, receiver, assets, shares);
            assets
        }

        /// @notice Returns amount of hSTRK corresponding to amount of STRK tokens
        /// @param assets Amount of STRK tokens
        /// @return Returns amount of hSTRK tokens
        fn preview_deposit(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        /// @notice Returns amount of STRK corresponding to amount of hSTRK tokens
        /// @param shares Amount of hSTRK tokens
        /// @return Returns amount of STRK tokens
        fn preview_mint(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        /// @notice Returns amount of STRK corresponding to amount of hSTRK tokens
        /// @param shares Amount of STRK tokens
        /// @return Returns amount of STRK tokens
        fn preview_redeem(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        /// @notice Returns amount of hSTRK corresponding to amount of STRK tokens
        /// @param assets Amount of STRK tokens
        /// @return Returns amount of hSTRK tokens
        fn preview_withdraw(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        /// @notice Withdraw amount of STRK corresponding to amount of hSTRK to user
        /// @param shares Amount of hSTRK user intends to burn 
        /// @param reciever Address where the amount of STRK is to be withdrawn
        /// @return Returns amount of STRK tokens to be withdrawn corresponding to the amount of hSTRK
        fn redeem(
            ref self: ComponentState<TContractState>,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            let caller = get_caller_address();
            let assets = self.preview_redeem(shares);
            self._withdraw(caller, receiver, owner, assets, shares);
            assets
        }

        /// @notice Returns total balance of STRK in the vault
        fn total_assets(self: @ComponentState<TContractState>) -> u256 {
            let dispatcher = ERC20ABIDispatcher { contract_address: self.ERC4626_asset.read() };
            dispatcher.balanceOf(get_contract_address())
        }

        /// @notice Withdraw STRK to user given by user as assets
        /// @param assets Amount of STRK user wants to withdraw 
        /// @param reciever Address where the amount of STRK is to be withdrawn
        /// @return Returns amount of hSTRK tokens user has to burn to withdraw @param(assets) amount of STRK
        fn withdraw(
            ref self: ComponentState<TContractState>,
            assets: u256,
            receiver: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            let caller = get_caller_address();
            let shares = self.preview_withdraw(assets);
            self._withdraw(caller, receiver, owner, assets, shares);

            shares
        }
    }


    #[embeddable_as(ERC4626MetadataImpl)]
    impl ERC4626Metadata<
        TContractState,
        +HasComponent<TContractState>,
        impl erc20: ERC20Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC4626Metadata<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.name()
        }
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_comp = get_dep_component!(ref self, erc20);
            erc20_comp.symbol()
        }
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.ERC4626_underlying_decimals.read() + self.ERC4626_offset.read()
        }
    }

    #[embeddable_as(ERC4626CamelImpl)]
    impl ERC4626Camel<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC4626HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IERC4626Camel<ComponentState<TContractState>> {
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply()
        }
        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }
        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.transfer_from(sender, recipient, amount)
        }

        /// @notice Stake STRK to Vault and mints liquid staking token 'hSTRK'
        /// @param shares Amount of htokens to convert 
        /// @return Returns amount of assets for particular amount of shares 
        fn convertToAssets(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        /// @notice Stake STRK to Vault and mints liquid staking token 'hSTRK'
        /// @param assets Amount of token to convert
        /// @return Returns amount of shares for particular amount of assets   
        fn convertToShares(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        fn previewDeposit(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        fn previewMint(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        fn previewRedeem(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        fn previewWithdraw(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        fn totalAssets(self: @ComponentState<TContractState>) -> u256 {
            let dispatcher = ERC20ABIDispatcher { contract_address: self.ERC4626_asset.read() };
            dispatcher.balanceOf(get_contract_address())
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl erc20: ERC20Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl Hooks: ERC4626HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalImplTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            asset: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            offset: u8
        ) {
            let dispatcher = ERC20ABIDispatcher { contract_address: asset };
            self.ERC4626_offset.write(offset);
            let decimals = dispatcher.decimals();
            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            erc20_comp_mut.initializer(name, symbol);
            self.ERC4626_asset.write(asset);
            self.ERC4626_underlying_decimals.write(decimals);
        // ! To register interface
        // let mut src5_component = get_dep_component_mut!(ref self, src5);
        // src5_component.register_interface(interface::IERC721_ID);
        // src5_component.register_interface(interface::IERC721_METADATA_ID);
        }

        fn _convert_to_assets(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            let supply: u256 = self.total_supply();
            if (supply == 0) {
                shares
            } else {
                (shares * self.total_assets()) / supply
            }
        }

        fn _convert_to_shares(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            let supply: u256 = self.total_supply();
            if (assets == 0 || supply == 0) {
                assets
            } else {
                (assets * supply) / self.total_assets()
            }
        }

        fn _deposit(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256
        ) {
            Hooks::before_deposit(ref self, caller, receiver, assets, shares);

            let dispatcher = ERC20ABIDispatcher { contract_address: self.ERC4626_asset.read() };
            dispatcher.transferFrom(caller, get_contract_address(), assets);
            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            erc20_comp_mut._mint(receiver, shares);
            self.emit(Deposit { sender: caller, owner: receiver, assets, shares });

            Hooks::after_deposit(ref self, caller, receiver, assets, shares);
        }

        fn _withdraw(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256
        ) {
            Hooks::before_withdraw(ref self, caller, receiver, owner, assets, shares);

            let mut erc20_comp_mut = get_dep_component_mut!(ref self, erc20);
            if (caller != owner) {
                let allowance = self.allowance(owner, caller);
                if (allowance != BoundedU256::max()) {
                    assert(allowance >= shares, ERC20Errors::APPROVE_FROM_ZERO);
                    erc20_comp_mut.ERC20_allowances.write((owner, caller), allowance - shares);
                }
            }

            erc20_comp_mut._burn(owner, shares);

            let dispatcher = ERC20ABIDispatcher { contract_address: self.ERC4626_asset.read() };
            dispatcher.transfer(receiver, assets);

            self.emit(Withdraw { sender: caller, receiver, owner, assets, shares });

            Hooks::before_withdraw(ref self, caller, receiver, owner, assets, shares);
        }

        fn _decimals_offset(self: @ComponentState<TContractState>) -> u8 {
            self.ERC4626_offset.read()
        }
    }
}

impl ERC4626HooksEmptyImpl<TContractState> of ERC4626Component::ERC4626HooksTrait<TContractState> {
    fn before_deposit(
        ref self: ERC4626Component::ComponentState<TContractState>,
        caller: ContractAddress,
        receiver: ContractAddress,
        assets: u256,
        shares: u256
    ) {}
    fn after_deposit(
        ref self: ERC4626Component::ComponentState<TContractState>,
        caller: ContractAddress,
        receiver: ContractAddress,
        assets: u256,
        shares: u256
    ) {}

    fn before_withdraw(
        ref self: ERC4626Component::ComponentState<TContractState>,
        caller: ContractAddress,
        receiver: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {}
    fn after_withdraw(
        ref self: ERC4626Component::ComponentState<TContractState>,
        caller: ContractAddress,
        receiver: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {}
}
