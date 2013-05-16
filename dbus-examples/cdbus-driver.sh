#!/bin/sh

if [ -z "$SED" ]; then
  SED="sed"
  command -v gsed > /dev/null && SED="gsed"
fi

# === Get connection parameters ===

dpy=$(echo -n "$DISPLAY" | tr -c '[:alnum:]' _)

if [ -z "$dpy" ]; then
  echo "Cannot find display."
  exit 1
fi

service="com.github.aaronhamilton.companion.${dpy}"
interface='com.github.aaronhamilton.companion'
object='/com/github/aaronhamilton/companion'
type_win='uint32'
type_enum='uint16'

# === DBus methods ===

# List all window ID companion manages (except destroyed ones)
dbus-send --print-reply --dest="$service" "$object" "${interface}.list_win"

# Ensure we are tracking focus
dbus-send --print-reply --dest="$service" "$object" "${interface}.opts_set" string:track_focus boolean:true

# Get window ID of currently focused window
focused=$(dbus-send --print-reply --dest="$service" "$object" "${interface}.find_win" string:focused | $SED -n 's/^[[:space:]]*'${type_win}'[[:space:]]*\([[:digit:]]*\).*/\1/p')

if [ -n "$focused" ]; then
  # Get invert_color_force property of the window
  dbus-send --print-reply --dest="$service" "$object" "${interface}.win_get" "${type_win}:${focused}" string:invert_color_force

  # Set the window to have inverted color
  dbus-send --print-reply --dest="$service" "$object" "${interface}.win_set" "${type_win}:${focused}" string:invert_color_force "${type_enum}:1"
else
  echo "Cannot find focused window."
fi

# Reset companion
sleep 3
dbus-send --print-reply --dest="$service" "$object" "${interface}.reset"

