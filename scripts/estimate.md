python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url https://mainnet.base.org
MANUAL_EPOCHS_PER_DAY=4 ROLLING_INTERVAL_SECONDS=1800 ROLLING_TEMPLATES=2 python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url "$BASE_RPC_URL"
python3 scripts/estimate_deploy_and_epoch_costs.py --json --gas-price-gwei 0.05 --eth-price-usd 3200

python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url https://mainnet.base.org --color always
MANUAL_EPOCHS_PER_DAY=50 ROLLING_TEMPLATES=7 python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url https://mainnet.base.org