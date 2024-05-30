use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp, stop_warp
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use hashstack_contracts::token::erc4626::IERC4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn INITIAL_SUPPLY() -> u256 {
    1000000000000000000000000000000
}

fn TOKEN_ADDRESS() -> ContractAddress {
    'token_address'.try_into().unwrap()
}

fn VAULT_ADDRESS() -> ContractAddress {
    'vault_address'.try_into().unwrap()
}

fn pow_256(self: u256, mut exponent: u8) -> u256 {
    if self.is_zero() {
        return 0;
    }
    let mut result = 1;
    let mut base = self;

    loop {
        if exponent & 1 == 1 {
            result = result * base;
        }

        exponent = exponent / 2;
        if exponent == 0 {
            break result;
        }

        base = base * base;
    }
}

fn deploy_token() -> (ERC20ABIDispatcher, ContractAddress) {
    let token = declare("ERC20Token").unwrap();
    let mut calldata = Default::default();
    Serde::serialize(@OWNER(), ref calldata);
    Serde::serialize(@INITIAL_SUPPLY(), ref calldata);

    let token_address = token.deploy(@calldata).unwrap();
    let dispatcher = ERC20ABIDispatcher { contract_address: token_address };
    (dispatcher, address)
}

fn deploy_contract() -> (ERC20ABIDispatcher, IERC4626Dispatcher) {
    let (token, token_address) = deploy_token();
    let mut calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TST";
    calldata.append_serde(token_address);
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append(0);
    let vault = declare("ERC4626").unwrap();
    let contract_address = vault.deploy(@calldata).unwrap();
    (token, IERC4626Dispatcher { contract_address })
}

#[test]
fn test_convert_to_assets() {
    let (asset, vault) = deploy_contract();
    let shares = pow_256(10,4);
    assert(vault.convert_to_assets(shares) == pow_256(10,4), "invalid shares");
}

fn test_convert_to_shares() {
    let (asset, vault) = deploy_contract();
    let assets = pow_256(10,4);
    assert(vault.convert_to_shares(assets) == pow_256(10,4), "invalid assets");
}

#[test]
fn deposit_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    assert(vault.deposit(amount, OWNER()) ==  vault.preview_deposit(amount), 'invalind converted shares');
    assert(vault.balanceOf(OWNER()) ==  vault.preview_deposit(amount), 'invalid balance of owner');
}

#[test]
fn mint_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    let minted = vault.preview_mint(1);
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    let _shares = vault.mint(10, OWNER());
    assert(vault.balanceOf(OWNER()) == vault.preview_mint(10), 'invalid mint shares');
}

#[test]
fn redeem_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    let shares = vault.deposit(amount, OWNER());
    assert(vault.balanceOf(OWNER()) == shares, 'invalid balance before');
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    let _redeemed = vault.redeem(shares, OWNER(), OWNER());
    assert(vault.balanceOf(OWNER()) == 0, 'invalid balance after');
}

#[test]
fn withdraw_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    let shares = vault.deposit(amount, OWNER());
    assert(vault.balanceOf(OWNER()) == shares, 'invalid balance before');
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    let _shares = vault.withdraw(amount, OWNER(), OWNER());
    assert(vault.balanceOf(OWNER()) == 0, 'invalid balance after');
}