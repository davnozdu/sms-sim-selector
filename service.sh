#!/system/bin/sh
# SMS SIM Selector - applies the saved SIM after boot and keeps it applied
#
# The framework re-picks the default SMS subscription every time the SIMs are
# re-initialised (modem restart, eSIM refresh, carrier config reload, a restart
# of com.android.phone) and once more when the user unlocks after a reboot. The
# physical slot wins that race because it reaches LOADED a few milliseconds
# before the eSIM, so a one-shot apply at boot is silently undone later on.
# We apply once the SIMs are up and then watch.

MODDIR=${0%/*}
PATH=/system/bin:/system/xbin:/vendor/bin:$PATH
export PATH

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
  sleep 5 || break
  system_alive || break
done

[ "$WATCH" = "1" ] || exit 0

# Watch loop. A SIM state change or the first unlock after boot is the signal
# that the framework is about to re-pick its defaults; the periodic verify is
# the safety net for everything else. Both read the config again, so a change
# made through Action is picked up without a reboot.
last_state=$(sim_state)
last_unlock=$(user_unlocked)
elapsed=0
guard=$BOOT_GUARD
fails=0

while true; do
  # a failing sleep means the system is going away - stop, do not spin
  sleep "$WATCH_INTERVAL" || exit 0
  system_alive || exit 0

  [ "$guard" -gt 0 ] && guard=$((guard - WATCH_INTERVAL))

  state=$(sim_state)
  unlock=$(user_unlocked)

  if [ "$state" != "$last_state" ] || [ "$unlock" != "$last_unlock" ]; then
    [ "$state" != "$last_state" ]   && log "SIM state changed: $last_state -> $state"
    [ "$unlock" != "$last_unlock" ] && log "user storage unlocked: $last_unlock -> $unlock"
    last_state=$state
    last_unlock=$unlock
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

  # verify often while the boot guard lasts, sparingly afterwards
  if [ "$guard" -gt 0 ]; then
    interval=$WATCH_INTERVAL
  else
    interval=$VERIFY_INTERVAL
  fi

  elapsed=$((elapsed + WATCH_INTERVAL))
  [ "$elapsed" -lt "$interval" ] && continue
  elapsed=0

  load_config
  now=$(current_sms_sub)

  # an unreadable value means the system is not answering, not a mismatch
  [ -z "$now" ] && continue
  [ "$now" = "$(sub_for_sim "$SMS_SIM")" ] && { fails=0; continue; }

  if apply_sim "$SMS_SIM"; then
    fails=0
  else
    fails=$((fails + 1))
    if [ "$fails" -ge 10 ]; then
      log "giving up after $fails failed attempts - check ISUB_CODE, see the README"
      exit 1
    fi
  fi
done
