#!/system/bin/sh
# SMS SIM Selector - Action button
# Vol+ = SIM 1 (physical), Vol- = SIM 2 (eSIM) -> applied instantly
# Power = keep the current selection and re-apply it

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_config

echo "==============================="
echo "     SMS SIM Selector"
echo "==============================="
echo ""
echo " Vol UP    -> SIM 1 (physical)"
echo " Vol DOWN  -> SIM 2 (eSIM)"
echo " POWER     -> keep $(sim_label "$SMS_SIM")"
echo ""
echo " Current default SMS SIM: $(sim_label "$SMS_SIM")"
echo " (system multi_sim_sms = $(current_sms_sub))"
echo ""
echo " Press a key... (${KEY_TIMEOUT}s timeout)"
echo ""

SEL=$SMS_SIM

while true; do
  KEY=$(wait_key)
  if [ $? -ne 0 ]; then
    echo " ! No key pressed, keeping $(sim_label "$SEL")"
    break
  fi
  case "$KEY" in
    KEY_VOLUMEUP)   SEL=1; break ;;
    KEY_VOLUMEDOWN) SEL=2; break ;;
    KEY_POWER)      break ;;
  esac
done

SMS_SIM=$SEL
save_config

echo " > $(sim_label "$SMS_SIM")"
echo ""
if apply_sim "$SMS_SIM"; then
  echo " ==============================="
  echo "  APPLIED: $(sim_label "$SMS_SIM")"
  echo "  Saved and re-applied on every boot."
  echo "  You can close this window."
  echo " ==============================="
else
  echo " ! Failed to apply, see $LOG_FILE"
fi
echo ""
echo " System multi_sim_sms = $(current_sms_sub)"
