$PIPE = "\\.\\pipe\\cardano-node-mainnet"
$CLI = "C:\Program Files\Daedalus Mainnet\cardano-cli.exe"
$ENV:CARDANO_NODE_SOCKET_PATH = $PIPE
$KeyFolder = "C:\Temp\Keys"
$ScriptVersion = "1.24.2"

If (!(test-path $KeyFolder)) {
    New-Item -ItemType Directory -Force -Path $KeyFolder 
}

Function Address-Balance-Submenu($type, $info) {
    Write-Host "==== view balance menu ====" -ForegroundColor Green
    Write-Host "(1) View $info address Stored in KeyFolder: $KeyFolder" 
    Write-Host "(2) Enter $info address" 
    $Input = read-host "Please make a selection"

    If ($Input -eq '1') {
        Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
        ls $KeyFolder | select -ExpandProperty name
        $Input = read-host "Enter the name of the wallet you wish to view"
        $address = Get-Content ($KeyFolder + "\" + $input + "\" + "$info.addr")
        show-balance -Type $type -address $Address
        pause
    }

    If ($Input -eq '2') {
        $Address = read-host "Enter $info Address"
        cls
        show-balance -Type $type -address $Address
        pause
    }

}


Function Main-Menu {
    Write-Host "====Main Menu====" -ForegroundColor Green
    Write-Host "(1) Create New Payment & Stake Address Key Pairs" 
    Write-Host "(2) Register Stake Address on Block Chain" 
    Write-Host "(3) View Payment Address Balance" 
    Write-Host "(4) View Stake Address Rewards" 
    Write-Host "(5) Claim Rewards from Stake Address -> Payment Address" 
    Write-Host "(6) Delegate to Stake Pool" 
    Write-Host "(7) Send Funds To Payment\Wallet Address" 
    Write-Host "(8) Submit Json File to BlockChain (Eg VOTE.Json)"
    Write-Host "(9) Exit Script"
    Write-Host " "
}

Function show-balance($Type, $address) {
    Write-Host "----------------------------------------------------------------------------------------"
    Write-host $Address -ForegroundColor Green
    Write-host "----------------------------------------------------------------------------------------"
    & $CLI query $Type --address $Address --cardano-mode --mainnet --allegra-era
    Write-host "----------------------------------------------------------------------------------------"
}

Function Create-Address-Pair {
    $walletName = Read-Host "Enter Wallet Name eg CHEAP"
    $WalletPath = $KeyFolder + "\" + $walletName
    If (!(test-path $WalletPath)) {
        $output = New-Item -ItemType Directory -Force -Path $WalletPath
        & $CLI address key-gen --verification-key-file "$WalletPath\payment.vkey" --signing-key-file "$WalletPath\payment.skey"
        & $CLI stake-address key-gen --verification-key-file "$WalletPath\stake.vkey" --signing-key-file "$WalletPath\stake.skey"
        #Link Stake Address to Payment Address
        & $CLI  address build --payment-verification-key-file "$WalletPath\payment.vkey" --stake-verification-key-file "$WalletPath\stake.vkey" --out-file "$WalletPath\payment.addr" --mainnet
        & $CLI  stake-address build --stake-verification-key-file "$WalletPath\stake.vkey" --out-file "$WalletPath\stake.addr" --mainnet
        # Create Stake Address Cert For Registration Latter
        start-sleep 3
        & $CLI  stake-address registration-certificate --stake-verification-key-file "$WalletPath\stake.vkey" --out-file "$WalletPath\stakeaddr.cert"
        start-sleep 1
        $PaymentAddress = get-content "$WalletPath\Payment.addr"
        $StakeAddress = get-content "$WalletPath\Stake.addr"
        write-host "payment.skey, Payment.vkey, Stake.skey, Stake.vkey keypair files created in $WalletPath" -ForegroundColor Green
        Write-Host "Your Payment Address from $WalletPath\Payment.addr ="
        $PaymentAddress
        Write-Host "Your Stake Address from $WalletPath\Stake.addr ="
        $StakeAddress
        Write-Host "Please keep these keys safe and offline - do not give out your Payment.skey to ANYONE, people with this key can make transactions from your wallet!" -ForegroundColor Red
        Pause
    }
    else {
        Write-Host "Wallet $walletName Already Exists! Cannot Create" -ForegroundColor Red
    }

}

Function get-tip {
    [int]$tip = & $CLI  query tip --mainnet | ConvertFrom-Json | select -ExpandProperty slotNo
    $tip
}

Function sign-transaction ($txfilepath = "$WalletPath\tx.raw", $txsignedfilepath = "$WalletPath\tx.signed", $Keys) {
    & $CLI   transaction sign --tx-body-file $txfilepath $Keys --mainnet --out-file $txsignedfilepath
}

Function submit-transaction ($txsignedfilepath = "$WalletPath\tx.signed") {
    & $CLI  transaction submit --tx-file $txsignedfilepath --mainnet
}

Function calculate-minfee ($txfilepath = "$WalletPath\tx.raw", $txincount = 1, $txoutcount = 1, $protocoljson = "$WalletPath\protocol.json", $witnesscount = 1, $byronwitnesscount = 0) {
    & $CLI  query protocol-parameters --mainnet --allegra-era --out-file $protocoljson 
    & $CLI  transaction calculate-min-fee --tx-body-file $txfilepath --tx-in-count $txincount --tx-out-count $txoutcount --mainnet --protocol-params-file $protocoljson --witness-count $witnesscount --byron-witness-count $byronwitnesscount
}

Function Query-Utxo ($paymentaddress, $utxo) {
    & $CLI  query utxo --address $paymentaddress --cardano-mode --mainnet --allegra-era --out-file $utxo
    write-host "---- UTXO Balances for $paymentaddress ---" -ForegroundColor Green
    get-content $WalletPath\balance.txt
    Write-Host "Reminder Balace must exist on the payment wallet to pay fees to register if funds are missing send ada to cover fees"
}

Function Register-Stake-Address {
    Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
    ls $KeyFolder | select -ExpandProperty name
    $walletName = read-host "Enter the name of the wallet you for the stake address to register"
    $WalletPath = $KeyFolder + "\" + $walletName 
    $paymentaddress = get-content ($WalletPath + "\" + "payment.addr")
    $CertPath = $WalletPath + "\" + "stakeaddr.cert"
    If ((test-path $CertPath)) {
        Query-Utxo -paymentaddress $paymentaddress -utxo "$WalletPath\balance.txt"
        $utxo = Read-Host "Enter your payment wallet utxo that will be used to pay fee followed by the hash number example: 5d19a49..dd0f73fe#0"
        $utxobalance = get-content $WalletPath\balance.txt | ConvertFrom-Json | select -ExpandProperty $utxo | select -ExpandProperty amount

        & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+0 --ttl ((get-tip) + 2000) --fee 0 --out-file $WalletPath\tx.raw --certificate-file $CertPath
        $minfee = ((calculate-minfee).Split(" ")[0])
        $utxobalancelessfees = $utxobalance - $minfee - (get-content "$WalletPath\protocol.json" | ConvertFrom-Json | select -ExpandProperty keyDeposit)
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+$utxobalancelessfees --ttl ((get-tip) + 2000) --fee $minfee --out-file $WalletPath\tx.raw --certificate-file $CertPath
        & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --signing-key-file $WalletPath\stake.skey --mainnet --out-file $WalletPath\tx.signed
        Write-host "Submit Stake Address Registration to Blockchain at a fee of $minfee deducted from $utxo" -ForegroundColor red
        $Response = read-host "Type Yes to Submit or press any key to cancel" 
        if ($Response -eq "Yes") {
            Try {
                submit-transaction
                Remove-item $WalletPath\tx.raw
                Remove-item $WalletPath\tx.signed
                Remove-item $CertPath
                Remove-item $WalletPath\balance.txt
            }
            catch { $_ }

        }


    }
    else {
        Write-Host "Stake Address for $WalletName is already registered" -ForegroundColor Red
    }

}

Function Delegate-To-Pool {
    Write-Host "==== Pool Delegation Center ====" -ForegroundColor Green
    Write-Host "Support This Tool By Delegating to TICKER: CHEAP ;)" -ForegroundColor Gray
    write-host "To Delegate to a pool you will need the Pool vKey - this can be found on https://pooltool.io and can be copied to your clipboard" -ForegroundColor Gray
    write-host "Your Stake Address Must Be Registered to the Blockchain and your payment Address must be funded to pay fees" -ForegroundColor Red
    write-host "----" -ForegroundColor Gray
    $PoolVKey = Read-host "enter the Pool Vkey to wish to Delegate to"
    $PoolVkeyJson = @"
{
    "type": "StakePoolVerificationKey_ed25519",
    "description": "Stake Pool Operator Verification Key",
    "cborHex": "$PoolVKey"
}
"@ 
    Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
    ls $KeyFolder | select -ExpandProperty name
    $walletName = read-host "Enter the name of the wallet you you wish to delegate from"
    $WalletPath = $KeyFolder + "\" + $walletName 
    $paymentaddress = get-content ($WalletPath + "\" + "payment.addr")
    $poolVkeyJson | Out-File $WalletPath\Pool.key -Encoding ascii
    Query-Utxo -paymentaddress $paymentaddress -utxo "$WalletPath\balance.txt"
    $utxo = Read-Host "Enter your payment wallet utxo that will be used to pay fee followed by the hash number example: 5d19a49..dd0f73fe#0"
    $utxobalance = get-content $WalletPath\balance.txt | ConvertFrom-Json | select -ExpandProperty $utxo | select -ExpandProperty amount

    & $CLI  stake-address delegation-certificate --stake-verification-key-file $WalletPath\stake.vkey --cold-verification-key-file $WalletPath\Pool.key --out-file $WalletPath\delegation.cert

    & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+0 --ttl ((get-tip) + 2000) --fee 0 --out-file $WalletPath\tx.raw --certificate-file $WalletPath\delegation.cert
    $minfee = ((calculate-minfee).Split(" ")[0])
    $utxobalancelessfees = $utxobalance - $minfee 
    & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+$utxobalancelessfees --ttl ((get-tip) + 2000) --fee $minfee --out-file $WalletPath\tx.raw --certificate-file $WalletPath\delegation.cert
    & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --signing-key-file $WalletPath\stake.skey --mainnet --out-file $WalletPath\tx.signed

    Write-host "Submit wallet $walletName delegation to Blockchain at a fee of $minfee deducted from $utxo" -ForegroundColor red
    $Response = read-host "Type Yes to Submit or press any key to cancel" 
    if ($Response -eq "Yes") {
        Try {
            submit-transaction
            Remove-item $WalletPath\tx.raw
            Remove-item $WalletPath\tx.signed
            Remove-item $WalletPath\balance.txt
        }
        catch { $_ }
    }
}

Function Send-Funds {
    Write-Host "==== Send Transaction ====" -ForegroundColor Green
    Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
    ls $KeyFolder | select -ExpandProperty name
    $walletName = read-host "Enter the name of the wallet you you wish to send funds from"

    $WalletPath = $KeyFolder + "\" + $walletName 
    $paymentaddress = get-content ($WalletPath + "\" + "payment.addr")
    Query-Utxo -paymentaddress $paymentaddress -utxo "$WalletPath\balance.txt"
    $utxo = Read-Host "Enter the utxo for the transaction by the hash number example: 5d19a49..dd0f73fe#0"

    $SendTo = read-host "Enter the Address you wish to send funds to"
    $SendAll = read-host "Do you want to send all love laces avaiable on this UTXO? Yes or No" 
    $utxobalance = get-content $WalletPath\balance.txt | ConvertFrom-Json | select -ExpandProperty $utxo | select -ExpandProperty amount

    If ($SendAll -eq "Yes") {
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $SendTo+0 --ttl ((get-tip) + 2000) --fee 0 --out-file $WalletPath\tx.raw 
        $minfee = ((calculate-minfee).Split(" ")[0])
        $SendAmount = $utxobalance - $minfee
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $SendTo+$SendAmount --ttl ((get-tip) + 2000) --fee $minfee --out-file $WalletPath\tx.raw 
        & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --mainnet --out-file $WalletPath\tx.signed
    }
    Else {
        $SendAmount = read-host "Enter the Amount of Love Laces to send (1 ADA = 1000000 lovelace)"
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+0 --tx-out $SendTo+0 --ttl ((get-tip) + 2000) --fee 0 --out-file $WalletPath\tx.raw 
        $minfee = ((calculate-minfee -txoutcount 2).Split(" ")[0]) 
        $returnAmount = $utxobalance - $SendAmount - $minfee
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $SendTo+$SendAmount --tx-out $paymentaddress+$returnAmount --ttl ((get-tip) + 2000) --fee $minfee --out-file $WalletPath\tx.raw 
        & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --mainnet --out-file $WalletPath\tx.signed
    }

    Write-host "Are you sure you wish to send $SendAmount lovelaces at a fee of $minfee to address: $SendTo" -ForegroundColor red
    $Response = read-host "Type Yes to Submit or press any key to cancel" 
    if ($Response -eq "Yes") {
        Try {
            submit-transaction
            Remove-item $WalletPath\tx.raw
            Remove-item $WalletPath\tx.signed
            Remove-item $WalletPath\balance.txt
        }
        catch { $_ }
    }
}

Function Claim-Rewards {
    Write-Host "==== Send Rewards Transaction ====" -ForegroundColor Green
    Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
    ls $KeyFolder | select -ExpandProperty name
    $walletName = read-host "Enter the name of the wallet you you wish to claim reward funds from"

    $WalletPath = $KeyFolder + "\" + $walletName 
    $paymentaddress = get-content ($WalletPath + "\" + "payment.addr")
    $stakeaddress = get-content ($WalletPath + "\" + "stake.addr")

    $RewardsBalance = show-balance -address $stakeaddress -Type "stake-address-info"
    $RewardsBalance
    Write-host "==== Transaction Fee Required from Payment Address for Transfer ======"
    $stakeskey = $WalletPath + "\" + "stake.skey"
    Query-Utxo -paymentaddress $paymentaddress -utxo "$WalletPath\balance.txt" 
    $utxo = Read-Host "Enter the utxo of your payment address to pay transaction fee by the hash number example: 5d19a49..dd0f73fe#0"
    $RewardsBalanceLoveLaceOnly = $RewardsBalance | ConvertFrom-Json | select *  | select -ExpandProperty SyncRoot  | select -ExpandProperty rewardAccountBalance
    $Withdrawal = $stakeaddress + "+" + $RewardsBalanceLoveLaceOnly


    $SendTo = read-host "Enter the Address you wish to send funds to"
    $SendAll = read-host "Do you want to send all love laces avaiable on this UTXO? Yes or No" 
    $utxobalance = get-content $WalletPath\balance.txt | ConvertFrom-Json | select -ExpandProperty $utxo | select -ExpandProperty amount

    If ($SendAll -eq "Yes") {
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $SendTo+0 --ttl ((get-tip) + 2000) --fee 0 --withdrawal $Withdrawal --out-file $WalletPath\tx.raw 
        $minfee = ((calculate-minfee -txincount 2).Split(" ")[0])
        $lovelacesToReturn = $utxobalance - $minfee
        $SendAmount = $RewardsBalanceLoveLaceOnly
        & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+$lovelacesToReturn --tx-out $SendTo+$SendAmount --ttl ((get-tip) + 2000) --fee $minfee --withdrawal $Withdrawal --out-file $WalletPath\tx.raw 
        & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --signing-key-file $WalletPath\stake.skey --mainnet --out-file $WalletPath\tx.signed
        Write-host "Are you sure you wish to send $SendAmount lovelaces at a fee of $minfee to address: $SendTo" -ForegroundColor red
        $Response = read-host "Type Yes to Submit or press any key to cancel"
    }

 
    if ($Response -eq "Yes") {
        Try {
            submit-transaction
            Remove-item $WalletPath\tx.raw
            Remove-item $WalletPath\tx.signed
            Remove-item $WalletPath\balance.txt
        }
        catch { $_ }
    }
}

Function Submit-json-file {
    Write-Host "==== Submit Json File  ====" -ForegroundColor Green
    $JsonPath = Read-Host "Enter the path to your Json file (eg: C:\temp\vote.json):"
    Write-Host "Your Current Wallets in: $KeyFolder are as below:" 
    ls $KeyFolder | select -ExpandProperty name
    $walletName = read-host "Enter the name of the wallet you you wish use for the transaction Fees"

    $WalletPath = $KeyFolder + "\" + $walletName 
    $paymentaddress = get-content ($WalletPath + "\" + "payment.addr")
    Query-Utxo -paymentaddress $paymentaddress -utxo "$WalletPath\balance.txt"
    $utxo = Read-Host "Enter the utxo for the transaction by the hash number example: 5d19a49..dd0f73fe#0"
    $utxobalance = get-content $WalletPath\balance.txt | ConvertFrom-Json | select -ExpandProperty $utxo | select -ExpandProperty amount

    & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+0 --ttl ((get-tip) + 2000) --fee 0 --out-file $WalletPath\tx.raw --metadata-json-file $JsonPath
    
    $minfee = ((calculate-minfee).Split(" ")[0])  
    
    $returnAmount = $utxobalance - $minfee
    & $CLI  transaction build-raw --tx-in $utxo --tx-out $paymentaddress+$returnAmount --ttl ((get-tip) + 2000) --fee $minfee --out-file $WalletPath\tx.raw --metadata-json-file $JsonPath
    & $CLI  transaction sign --tx-body-file $WalletPath\tx.raw --signing-key-file $WalletPath\payment.skey --mainnet --out-file $WalletPath\tx.signed

    get-content $JsonPath
    Write-host "Are you sure you wish submit the above json from $jsonPath to the blockchain at a fee of $minfee" -ForegroundColor red
    $Response = read-host "Type Yes to Submit or press any key to cancel" 
    if ($Response -eq "Yes") {
        Try {
            submit-transaction
            Remove-item $WalletPath\tx.raw
            Remove-item $WalletPath\tx.signed
            Remove-item $WalletPath\balance.txt
        }
        catch { $_ }
    }

}


#==Start Script===#
write-host "This script is supported for $ScriptVersion for Shelley Mainnet... you are running.. " -ForegroundColor Yellow
write-host (& $CLI --version) -ForegroundColor Yellow
write-host "Please make sure the Daedalus Wallet is running and synced before proceeding" -ForegroundColor Gray
write-host "Your CLI Generated Wallets are set to store in $KeyFolder.. Please Ensure To Back These Up" -ForegroundColor Gray
start-sleep 3
do {
    Main-Menu
    $input = Read-Host "Please make a selection"
    switch ($input) {
        '1' {
            cls
            Create-Address-Pair
        } '2' {
            cls
            Register-Stake-Address
        } '3' {
            cls
            Address-Balance-Submenu -type "utxo" -info "payment"
        } '4' {
            cls
            Address-Balance-Submenu -type "stake-address-info" -info "stake"
        } '5' {
            cls
            Claim-Rewards
        } '6' {
            cls
            Delegate-To-Pool
        } '7' {
            cls
            Send-Funds
        } '8' {
            cls
            Submit-json-file
        } 'q' {
            return
        }
    }  
}
until ($input -eq '9')
