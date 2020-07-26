# Windows Cardano-CLI PoSH Tools

-- DISCLAIMER: This guide is for educational purposes only. Do not use in production with real funds. By using scripts and information in this repository, you assume sole risk and waive any claims of liability against the author.

This tool is designed help pool pledgers/co-owners to simplify the cardano command line interface documented on [ cardano docs](https://docs.cardano.org/projects/cardano-node/en/latest/stake-pool-operations/keys_and_addresses.html). Using windows and working along side the daedalus wallet pledgers/owners can generate payment and stake keys which pool operators can use in stake pool [registration](https://docs.cardano.org/projects/cardano-node/en/latest/stake-pool-operations/register_key.html). Hoping these features are added to the wallets to avoid the need for using cardano-cli and such tools as this.

# New Features!

- Create CardanoCLI Payment & Stake Address Key Pairs
- Register your Stake Address with the blockchain
- Delegate to Stake Pool
- Send Funds from CLI Addresses to other wallet types
- Claim rewards from CLI stake address & send to daedalus

> **NEVER** give out your payment.skey or
> payment.vkey to anyone, as these are used
> to sign and submit trasactions. Currently
> pool operators are required to have access
> to your stake.skey & stake.vkey to register
> a pledger as an owner on the pool certificate.
> If in doubt always verify with the community.
> Keep these files offline for added security.

### Installation

Windows-Cardano-CLI-Tools.ps1 works along side theDaedalus wallet, this must first be installed and synced.

1. Install Testnet Daedalus from https://testnets.cardano.org/en/shelley/get-started/wallet/
2. Open and Sync Daealus, create and fund a wallet (using your ITN keywords, faucet or snapshot balance)
3. Clone / Copy Windows-Cardano-CLI-Tools.ps1 from github to your local windows machine.
4. Open Powershell ISE on your local machine
5. Open Windows-Cardano-CLI.ps1
6. On line 4 update your key folder to where you want to store you key files for each wallet you create (Recommend targeting USB thumb drive)

![01-setup.gif](https://github.com/cheapstaking/Windows-CardanoCLI-PoSH/blob/master/img/01-Setup.gif)

#### Creating a CLI wallet for Payment & Stake Addresses

1. Run Windows-Cardano-CLI.ps1 to execute the tool
2. Press 1 to create a new keypair and give the wallet a name
3. Copy the payment.addr address from the screen and send funds using daedalus (Funds will be required in order to pay fees to register your stake address and to delegate to your pool - if you are pledging funds held on this address will be your pledge delegation)
4. Press 2 to register your stake address (Required before you can delegate or register addresses as a stakepool owner/pledger)
5. Copy paste the UTXO in the payment wallet that will be used to deduct fees

![02-KeyCreate.gif](https://github.com/cheapstaking/Windows-CardanoCLI-PoSH/blob/master/img/02-KeyCreate.gif)

> A stake address holds all your stake rewards, or if your a pool owner all margins, costs and owner pledge delegation rewards. Reward funds held here can be sent to a payment address using the stake.vkey & stake.skey

#### Delegating to a Pool

If keys have been generated in order to pledge to a pool, your pool operator will have requested your stake keys in order to complete the pool registration. After the pool is registered you must then delegate your wallet to that pool to meet the declared pledge level in the pool registration.

1. Using Windows-Cardano-CLI.ps1 press option 6
2. Paste in the pool verification key (Pool vkey) from your pool operator OR copy from [pooltool](https://pooltool.io)

![03-Delegation.gif](https://github.com/cheapstaking/Windows-CardanoCLI-PoSH/blob/master/img/03-Delegation.gif)

#### Sending Funds from CLI Payment Address

![04-Transactions.gif](https://github.com/cheapstaking/Windows-CardanoCLI-PoSH/blob/master/img/04-Transactions.gif)

#### Claiming Stake Address Rewards

![05-ClaimRewards.gif](https://github.com/cheapstaking/Windows-CardanoCLI-PoSH/blob/master/img/05-ClaimRewards.gif)
