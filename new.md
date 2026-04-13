asyam@LAPTOP-IBEUNTHH:~/dev/Project/RetroPick/V1$ # Generate a new keypair for the program
solana-keygen new -o target/deploy/retropick_market_engine_colosseum-keypair.json --no-bip39-passphrase

# Get the new program ID
solana address -k target/deploy/retropick_market_engine_colosseum-keypair.json
Generating a new keypair
Wrote new keypair to target/deploy/retropick_market_engine_colosseum-keypair.json
===================================================================================
pubkey: ArsTnEn12gNxyZrMdrQkKmTVcnTwACyvQ8o7rs7TsiUD
===================================================================================
Save this seed phrase to recover your new keypair:
rubber merit february ancient input display way hand daughter deposit intact almost
===================================================================================
ArsTnEn12gNxyZrMdrQkKmTVcnTwACyvQ8o7rs7TsiUD