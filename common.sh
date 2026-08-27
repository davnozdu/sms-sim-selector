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

# apply_sim <1|2>
apply_sim() {
  local sim="$1"
  local sub
  sub=$(sub_for_sim "$sim")
  local out
  out=$(service call isub "$ISUB_CODE" i32 "$sub" 2>&1)
  local rc=$?
  log "apply $(sim_label "$sim") -> service call isub $ISUB_CODE i32 $sub (rc=$rc) $out"
  log "multi_sim_sms is now: $(current_sms_sub)"
  return $rc
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
