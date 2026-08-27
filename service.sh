#!/system/bin/sh
# SMS SIM Selector - applies the saved SIM after boot

MODDIR=${0%/*}
. "$MODDIR/common.sh"

# wait for the system to finish booting
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
  sleep 2
  i=$((i + 1))
done

# give the telephony stack time to register the subscriptions
sleep 20

load_config
log "boot: applying saved SIM ($(sim_label "$SMS_SIM"))"

# retry a few times, subscriptions can appear late
n=0
while [ $n -lt 5 ]; do
  apply_sim "$SMS_SIM" && break
  n=$((n + 1))
  sleep 10
done
