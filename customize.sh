#!/system/bin/sh
# SMS SIM Selector - installer

SKIPUNZIP=0

. "$MODPATH/common.sh"

load_config
save_config

ui_print ""
ui_print "  SMS SIM Selector"
ui_print "  ----------------"
ui_print "  Default SMS SIM: $(sim_label "$SMS_SIM")"
ui_print ""
ui_print "  Open the module list and tap Action to change it:"
ui_print "    Vol UP   -> SIM 1 (physical)"
ui_print "    Vol DOWN -> SIM 2 (eSIM)"
ui_print "    POWER    -> confirm"
ui_print ""
ui_print "  The choice is re-applied on every boot."
ui_print ""

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/action.sh"    0 0 0755
set_perm "$MODPATH/service.sh"   0 0 0755
set_perm "$MODPATH/common.sh"    0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
