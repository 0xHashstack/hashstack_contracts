use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp, stop_warp
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use hashstack_contracts::token::erc4626::IERC4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use hashstack_contracts::utils::math::{pow_256};
use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn INITIAL_SUPPLY() -> u256 {
    1000000000000000000000000000000
}

fn deploy_token() -> (ERC20ABIDispatcher, ContractAddress) {
    let contract = declare("ERC20Token").unwrap();
    let mut calldata = Default::default();
    Serde::serialize(@OWNER(), ref calldata);
    Serde::serialize(@INITIAL_SUPPLY(), ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = ERC20ABIDispatcher { contract_address };
    (dispatcher, contract_address)
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
    let vault = declare("ERC4626Contract").unwrap();
    let (contract_address, _) = vault.deploy(@calldata).unwrap();
    (token, IERC4626Dispatcher { contract_address })
}

#[test]
fn test_initialization(){
    let (asset, vault) = deploy_contract();
    assert!(asset.total_supply() == INITIAL_SUPPLY(), "Initial supply not matched");
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TST";
    assert!(vault.name() == name, "Name not matched");
    assert!(vault.symbol() == symbol, "Symbol not matched");
    assert!(vault.total_supply() == 0, "Total supply must be 0 initialy");
    assert!(vault.total_assets() == 0, "Total assets must be 0 initialy");
    assert!(vault.decimals() == 18, "Decimals must be 18");

}

#[test]
fn test_convert_to_assets() {
    let ( _, vault) = deploy_contract();
    let shares = pow_256(10,2);
    assert!(vault.convert_to_assets(shares) == 100, "invalid shares");
}

#[test]
fn test_convert_to_shares() {
    let ( _, vault) = deploy_contract();
    let assets = pow_256(10,2);
    assert!(vault.convert_to_shares(assets) == 100, "invalid assets");
}

#[test]
fn deposit_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    let result = vault.preview_deposit(amount);
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    assert!(vault.deposit(amount, OWNER()) ==  result, "invalind converted shares");
}

#[test]
fn mint_flow_test(){
    let (asset, vault) = deploy_contract();
    let amount = asset.balanceOf(OWNER());
    start_prank(CheatTarget::One(asset.contract_address), OWNER());
    asset.approve(vault.contract_address, amount);
    stop_prank(CheatTarget::One(asset.contract_address));
    let minted = vault.preview_mint(amount);
    start_prank(CheatTarget::One(vault.contract_address), OWNER());
    assert!(vault.mint(amount, OWNER()) == minted, "invalid mint shares");
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
    assert!(asset.balanceOf(OWNER()) == 0, "invalid balance before");
    let _redeemed = vault.redeem(shares, OWNER(), OWNER());
    assert!(asset.balanceOf(OWNER()) == amount, "invalid balance after");
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
    assert!(asset.balanceOf(OWNER()) == 0, "invalid balance before");
    let _shares = vault.withdraw(shares, OWNER(), OWNER());
    assert!(asset.balanceOf(OWNER()) == amount, "invalid balance after");
}