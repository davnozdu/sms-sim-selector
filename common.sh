#!/system/bin/sh
# SMS SIM Selector - shared helpers
# Sourced by action.sh, service.sh and customize.sh

CONF_DIR=/data/adb/sms_sim_selector
CONF_FILE=$CONF_DIR/config
LOG_FILE=$CONF_DIR/log.txt

# Defaults. SUB_SIM* are the arguments passed to `service call isub <ISUB_CODE> i32 <sub>`
# On most devices sub id 2 is the physical slot and sub id 1 is the eSIM slot.
DEF_SMS_SIM=1
DEF_SUB_SIM1=2
DEF_SUB_SIM2=1
DEF_ISUB_CODE=37
# 1 = keep re-applying the choice after boot, 0 = apply once at boot only
DEF_WATCH=1
# seconds between two cheap SIM state checks
DEF_WATCH_INTERVAL=10
# seconds between two full checks of the system value
DEF_VERIFY_INTERVAL=60
# seconds to wait after the SIMs are loaded, so the framework picks its own
# defaults first and we get the last word
DEF_SETTLE_DELAY=15
# seconds after boot during which the system value is verified every
# WATCH_INTERVAL instead of every VERIFY_INTERVAL - the framework re-picks its
# defaults once more when the user unlocks the device
DEF_BOOT_GUARD=600

log() {
  mkdir -p "$CONF_DIR" 2>/dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
  # keep the log small
  if [ "$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 200 ]; then
    tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

load_config() {
  mkdir -p "$CONF_DIR" 2>/dev/null
  [ -f "$CONF_FILE" ] && . "$CONF_FILE"
  SMS_SIM=${SMS_SIM:-$DEF_SMS_SIM}
  SUB_SIM1=${SUB_SIM1:-$DEF_SUB_SIM1}
  SUB_SIM2=${SUB_SIM2:-$DEF_SUB_SIM2}
  ISUB_CODE=${ISUB_CODE:-$DEF_ISUB_CODE}
  WATCH=${WATCH:-$DEF_WATCH}
  WATCH_INTERVAL=${WATCH_INTERVAL:-$DEF_WATCH_INTERVAL}
  VERIFY_INTERVAL=${VERIFY_INTERVAL:-$DEF_VERIFY_INTERVAL}
  SETTLE_DELAY=${SETTLE_DELAY:-$DEF_SETTLE_DELAY}
  BOOT_GUARD=${BOOT_GUARD:-$DEF_BOOT_GUARD}
  case "$SMS_SIM" in 1|2) ;; *) SMS_SIM=$DEF_SMS_SIM ;; esac
}

save_config() {
  mkdir -p "$CONF_DIR" 2>/dev/null
  cat > "$CONF_FILE" <<CFG
# SMS SIM Selector configuration
# SMS_SIM: which SIM becomes the default for SMS (1 or 2)
SMS_SIM=$SMS_SIM
# sub id used by "service call isub \$ISUB_CODE i32 <sub>"
SUB_SIM1=$SUB_SIM1
SUB_SIM2=$SUB_SIM2
ISUB_CODE=$ISUB_CODE
# WATCH=1 re-applies the choice whenever the system overwrites it
# (the framework re-picks the default SMS SIM on every SIM re-initialisation)
WATCH=$WATCH
WATCH_INTERVAL=$WATCH_INTERVAL
VERIFY_INTERVAL=$VERIFY_INTERVAL
SETTLE_DELAY=$SETTLE_DELAY
BOOT_GUARD=$BOOT_GUARD
CFG
  chmod 644 "$CONF_FILE" 2>/dev/null
}

sub_for_sim() {
  case "$1" in
    1) echo "$SUB_SIM1" ;;
    2) echo "$SUB_SIM2" ;;
    *) echo "$SUB_SIM1" ;;
  esac
}

sim_label() {
  case "$1" in
    1) echo "SIM 1 (physical)" ;;
    2) echo "SIM 2 (eSIM)" ;;
    *) echo "SIM $1" ;;
  esac
}

current_sms_sub() {
  settings get global multi_sim_sms 2>/dev/null
}

# Cheap SIM state probe - a plain property read, no binder call.
# Looks like "LOADED,LOADED" once the telephony stack is up.
sim_state() {
  getprop gsm.sim.state
}

sim_loaded() {
  case "$(sim_state)" in
    *LOADED*) return 0 ;;
    *)        return 1 ;;
  esac
}

# True while the system is up. At shutdown /system is unmounted and every
# command we rely on disappears - including sleep, which would otherwise spin
# the watch loop at full speed and flood the log. [ -x ] is a shell builtin, so
# this costs nothing and still answers when no external command does. A restart
# of system_server alone is not covered here on purpose: /system stays mounted,
# the unreadable value is skipped by the loop and the choice is re-applied once
# the system answers again.
system_alive() {
  [ -x /system/bin/service ]
}

# Cheap unlock probe. Flips to "true" when the credential encrypted storage of
# the owner becomes available, i.e. when the user unlocks after a reboot - which
# is when the framework re-picks the default SMS subscription once more.
user_unlocked() {
  getprop sys.user.0.ce_available
}

# wait_sim_loaded [timeout_seconds]
wait_sim_loaded() {
  local max=${1:-180} waited=0
  while ! sim_loaded; do
    sleep 2
    waited=$((waited + 2))
    [ "$waited" -ge "$max" ] && return 1
  done
  return 0
}

# apply_sim <1|2>
# Returns 0 only when the system value really is the requested one afterwards:
# `service call` reports success even when the call changed nothing.
apply_sim() {
  local sim="$1"
  local sub before after out rc
  sub=$(sub_for_sim "$sim")
  before=$(current_sms_sub)
  out=$(service call isub "$ISUB_CODE" i32 "$sub" 2>&1)
  rc=$?
  after=$(current_sms_sub)
  if [ "$after" = "$sub" ]; then
    [ "$before" != "$after" ] && \
      log "applied $(sim_label "$sim"): multi_sim_sms $before -> $after"
    return 0
  fi
  log "FAILED to apply $(sim_label "$sim"): service call isub $ISUB_CODE i32 $sub (rc=$rc) $out -- multi_sim_sms=$after"
  return 1
}

# Waits for a single key press (key down) and echoes the key name.
# Returns 1 if TIMEOUT_SECS elapsed without a press.
KEY_TIMEOUT=${KEY_TIMEOUT:-60}
wait_key() {
  local key="" waited=0 have_timeout=0
  command -v timeout >/dev/null 2>&1 && have_timeout=1
  while [ -z "$key" ]; do
    if [ "$have_timeout" = 1 ]; then
      key=$(timeout 1 getevent -qlc 1 2>/dev/null | \
        awk '$2=="EV_KEY" && ($4=="DOWN" || $4=="00000001") {print $3}')
      waited=$((waited + 1))
      [ "$waited" -ge "$KEY_TIMEOUT" ] && return 1
    else
      key=$(getevent -qlc 1 2>/dev/null | \
        awk '$2=="EV_KEY" && ($4=="DOWN" || $4=="00000001") {print $3}')
    fi
  done
  echo "$key"
  return 0
}
