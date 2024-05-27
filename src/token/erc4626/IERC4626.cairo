use starknet::ContractAddress;

#[starknet::interface]
trait IERC4626<TState> {
    // ************************************
    // * IERC20
    // ************************************
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // ************************************
    // * IERC4626
    // ************************************
    fn asset(self: @TState) -> starknet::ContractAddress;
    fn convert_to_assets(self: @TState, shares: u256) -> u256;
    fn convert_to_shares(self: @TState, assets: u256) -> u256;
    fn deposit(ref self: TState, assets: u256, receiver: starknet::ContractAddress) -> u256;
    fn mint(ref self: TState, shares: u256, receiver: starknet::ContractAddress) -> u256;
    fn preview_deposit(self: @TState, assets: u256) -> u256;
    fn preview_mint(self: @TState, shares: u256) -> u256;
    fn preview_redeem(self: @TState, shares: u256) -> u256;
    fn preview_withdraw(self: @TState, assets: u256) -> u256;
    fn redeem(
        ref self: TState,
        shares: u256,
        receiver: starknet::ContractAddress,
        owner: starknet::ContractAddress
    ) -> u256;
    fn total_assets(self: @TState) -> u256;
    fn withdraw(
        ref self: TState,
        assets: u256,
        receiver: starknet::ContractAddress,
        owner: starknet::ContractAddress
    ) -> u256;

    // ************************************
    // * MetaData
    // ************************************
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
}


#[starknet::interface]
trait IERC4626Metadata<TState> {
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
}


#[starknet::interface]
trait IERC4626Camel<TState> {
    fn totalSupply(self: @TState) -> u256;
    fn totalAssets(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn previewDeposit(self: @TState, assets: u256) -> u256;
    fn previewMint(self: @TState, shares: u256) -> u256;
    fn previewRedeem(self: @TState, shares: u256) -> u256;
    fn previewWithdraw(self: @TState, assets: u256) -> u256;
    fn convertToAssets(self: @TState, shares: u256) -> u256;
    fn convertToShares(self: @TState, assets: u256) -> u256;
}

