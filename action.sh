#!/system/bin/sh
# SMS SIM Selector - Action button
# Vol+ = SIM 1 (physical), Vol- = SIM 2 (eSIM), Power = confirm

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_config

echo "==============================="
echo "     SMS SIM Selector"
echo "==============================="
echo ""
echo " Vol UP    -> SIM 1 (physical)"
echo " Vol DOWN  -> SIM 2 (eSIM)"
echo " POWER     -> confirm & apply"
echo ""
echo " Current default SMS SIM: $(sim_label "$SMS_SIM")"
echo " (system multi_sim_sms = $(current_sms_sub))"
echo ""
echo " Waiting for a key... (${KEY_TIMEOUT}s timeout)"
echo ""

SEL=$SMS_SIM

while true; do
  KEY=$(wait_key)
  if [ $? -ne 0 ]; then
    echo " ! No key pressed, keeping $(sim_label "$SEL")"
    break
  fi
  case "$KEY" in
    KEY_VOLUMEUP)
      SEL=1
      echo " > selected: $(sim_label 1)"
      ;;
    KEY_VOLUMEDOWN)
      SEL=2
      echo " > selected: $(sim_label 2)"
      ;;
    KEY_POWER)
      echo " > confirmed: $(sim_label "$SEL")"
      break
      ;;
  esac
done

SMS_SIM=$SEL
save_config

echo ""
if apply_sim "$SMS_SIM"; then
  echo " Default SMS SIM set to $(sim_label "$SMS_SIM")"
else
  echo " ! Failed to apply, see $LOG_FILE"
fi
echo " System multi_sim_sms = $(current_sms_sub)"
echo ""
echo " The choice is saved and re-applied on every boot."
