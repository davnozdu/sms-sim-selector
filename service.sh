#!/system/bin/sh
# SMS SIM Selector - applies the saved SIM after boot and keeps it applied
#
# The framework re-picks the default SMS subscription every time the SIMs are
# re-initialised (modem restart, eSIM refresh, carrier config reload, a restart
# of com.android.phone). The physical slot wins that race because it reaches
# LOADED a few milliseconds before the eSIM, so a one-shot apply at boot is
# silently undone later on. We apply once the SIMs are up and then watch.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

# wait for the system to finish booting
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
  sleep 2
  i=$((i + 1))
done

load_config

# wait for the telephony stack to register the subscriptions, then let the
# framework finish choosing its own defaults before overriding them
wait_sim_loaded 180 || log "boot: SIMs not LOADED after 180s, applying anyway"
sleep "$SETTLE_DELAY"

log "boot: applying saved SIM ($(sim_label "$SMS_SIM"))"

n=0
while [ $n -lt 10 ]; do
  apply_sim "$SMS_SIM" && break
  n=$((n + 1))
  sleep 5
done

[ "$WATCH" = "1" ] || exit 0

# Watch loop. A SIM state change is the signal that the framework is about to
# re-pick its defaults; the periodic verify is the safety net for everything
# else. Both read the config again, so a change made through Action is picked
# up without a reboot.
last_state=$(sim_state)
elapsed=0

while true; do
  sleep "$WATCH_INTERVAL"

  state=$(sim_state)
  if [ "$state" != "$last_state" ]; then
    log "SIM state changed: $last_state -> $state"
    last_state=$state
    elapsed=0
    case "$state" in
      *LOADED*)
        sleep "$SETTLE_DELAY"
        load_config
        apply_sim "$SMS_SIM"
        ;;
    esac
    continue
  fi

  elapsed=$((elapsed + WATCH_INTERVAL))
  [ "$elapsed" -lt "$VERIFY_INTERVAL" ] && continue
  elapsed=0

  load_config
  [ "$(current_sms_sub)" = "$(sub_for_sim "$SMS_SIM")" ] || apply_sim "$SMS_SIM"
done
