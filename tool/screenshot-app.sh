#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# screenshot-app.sh - drive the app on an off-screen display and capture it.
#
# Screenshots for the README have to come from the real application, but running
# it straight from a headless session puts its window on whatever display the
# container can reach - which, in the dev container, is the developer's own
# desktop through WSLg. This script runs the app on a private Xvfb display
# instead: nothing appears on screen, the window size is reproducible, and the
# app starts against an empty home directory so no real project ever leaks into
# an image.
#
# Usage:
#   tool/screenshot-app.sh start [--size WxH] [--build] [--keep-home]
#   tool/screenshot-app.sh shot <file.png> [window-id]
#   tool/screenshot-app.sh click <x> <y>         # click at window coordinates
#   tool/screenshot-app.sh type <text>           # type into the focused window
#   tool/screenshot-app.sh key <keys>            # e.g. Return, ctrl+l
#   tool/screenshot-app.sh scroll up|down [n] [x y]  # n notches under x,y
#   tool/screenshot-app.sh windows               # list the windows on the display
#   tool/screenshot-app.sh home                  # print the isolated HOME
#   tool/screenshot-app.sh status                # display, window id, geometry
#   tool/screenshot-app.sh stop                  # kill the app, the WM and Xvfb
#
# `type` and `key` go to whichever window has the focus, so they reach the app's
# native file dialogs - separate X windows - as well as the app itself. `windows`
# lists them, and `shot` takes an id when a dialog is what needs capturing.
#
# A session survives between invocations, so a caller drives the UI one command
# at a time and looks at the PNG in between. Coordinates are the ones read off
# the previous capture: the window sits at the display origin, so window and
# screen coordinates are the same.
#
# Typical session:
#   tool/screenshot-app.sh start --build
#   tool/screenshot-app.sh shot /tmp/home.png
#   tool/screenshot-app.sh click 516 462
#   tool/screenshot-app.sh key ctrl+l
#   tool/screenshot-app.sh type "$(tool/screenshot-app.sh home)/demo.fountain"
#   tool/screenshot-app.sh key Return
#   tool/screenshot-app.sh shot /tmp/editor.png
#   tool/screenshot-app.sh stop
#
# Requires: Xvfb, openbox, xdotool, xwininfo, ImageMagick - all installed by the
# dev container image (.devcontainer/Dockerfile).
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
STATE_DIR="${OCPT_SCREENSHOT_DIR:-${TMPDIR:-/tmp}/ocpt-screenshot}"
STATE_FILE="$STATE_DIR/session"
RELEASE_BIN="$REPO_ROOT/build/linux/x64/release/bundle/open_cine_prod_tools"
DEBUG_BIN="$REPO_ROOT/build/linux/x64/debug/bundle/open_cine_prod_tools"

die() { echo "$*" >&2; exit 1; }

require_tools() {
  local missing=()
  for tool in Xvfb openbox xdotool xwininfo xdpyinfo import; do
    command -v "$tool" >/dev/null || missing+=("$tool")
  done
  [[ ${#missing[@]} -eq 0 ]] || die \
    "Missing: ${missing[*]}. Rebuild the dev container, or install them with:
  sudo apt-get install -y xvfb openbox xdotool x11-utils imagemagick"
}

load_session() {
  [[ -f "$STATE_FILE" ]] || die "No session running. Start one with: $0 start"
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  export DISPLAY="$OCPT_DISPLAY"
}

# Whether an X server is answering on that display. This is the only reliable
# test here: under WSLg /tmp/.X11-unix is mounted read-only, so Xvfb cannot
# create its socket file there and falls back to an abstract socket. Looking for
# the file would report every display as free and every server as never started.
display_is_up() {
  xdpyinfo -display "$1" >/dev/null 2>&1
}

# Xvfb refuses a display number already taken, and several agents may be
# capturing at once, so take the first free one rather than a fixed :99.
pick_display() {
  local n
  for n in $(seq 90 99); do
    display_is_up ":$n" || { echo ":$n"; return; }
  done
  die "No free display between :90 and :99."
}

cmd_start() {
  local size="1280x720" build=0 keep_home=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --size) size="${2:?--size needs WxH}"; shift 2 ;;
      --build) build=1; shift ;;
      --keep-home) keep_home=1; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]] || die "--size must look like 1440x900"
  local width="${BASH_REMATCH[1]}" height="${BASH_REMATCH[2]}"

  require_tools
  [[ -f "$STATE_FILE" ]] && die "A session is already running. Stop it with: $0 stop"

  if [[ $build -eq 1 ]]; then
    echo "Building the Linux release bundle..."
    (cd "$REPO_ROOT" && flutter build linux --release)
  fi

  local binary
  if [[ -x "$RELEASE_BIN" ]]; then binary="$RELEASE_BIN"
  elif [[ -x "$DEBUG_BIN" ]]; then binary="$DEBUG_BIN"
  else die "No Linux build found. Run '$0 start --build', or 'flutter build linux --release'."
  fi

  local display; display=$(pick_display)
  mkdir -p "$STATE_DIR"
  local app_home="$STATE_DIR/home"
  [[ $keep_home -eq 1 ]] || rm -rf "$app_home"
  mkdir -p "$app_home"

  # The screen is larger than the window so a resized or dialog-covered window
  # still has room; the window itself is what gets captured.
  Xvfb "$display" -screen 0 "$((width + 320))x$((height + 280))x24" -nolisten tcp \
    >"$STATE_DIR/xvfb.log" 2>&1 &
  local xvfb_pid=$!
  # Wait for the server to answer rather than sleeping a guessed amount.
  local i
  for i in $(seq 1 50); do
    display_is_up "$display" && break
    sleep 0.2
  done
  display_is_up "$display" || die "Xvfb failed to start (see $STATE_DIR/xvfb.log)."

  # Without a window manager the app cannot be resized: it keeps the 1280x720 it
  # asks for at startup and ignores any XResizeWindow.
  DISPLAY="$display" setsid openbox >"$STATE_DIR/openbox.log" 2>&1 &
  local wm_pid=$!

  # Three things matter in this launch, and each one has bitten:
  #  - WAYLAND_DISPLAY unset and GDK_BACKEND=x11: GTK prefers Wayland when it is
  #    advertised, and in the dev container that is the developer's own WSLg
  #    compositor. The app would open on their desktop and never appear here.
  #  - HOME pointed at an empty directory: the home screen lists recent projects
  #    with their full paths, so the real one would end up in the screenshots.
  #  - setsid: the app outlives the shell that started it, which is what makes a
  #    session usable across several invocations of this script.
  env -u WAYLAND_DISPLAY \
    HOME="$app_home" \
    DISPLAY="$display" \
    GDK_BACKEND=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    setsid "$binary" >"$STATE_DIR/app.log" 2>&1 &
  local app_pid=$!

  local wid=""
  for i in $(seq 1 60); do
    wid=$(DISPLAY="$display" xdotool search --name '^open_cine_prod_tools$' 2>/dev/null | head -1 || true)
    [[ -n "$wid" ]] && break
    sleep 0.5
  done
  [[ -n "$wid" ]] || die "The app window never appeared (see $STATE_DIR/app.log)."

  cat >"$STATE_FILE" <<STATE
OCPT_DISPLAY=$display
OCPT_WID=$wid
OCPT_APP_HOME=$app_home
OCPT_XVFB_PID=$xvfb_pid
OCPT_WM_PID=$wm_pid
OCPT_APP_PID=$app_pid
STATE

  if [[ "$width" != "1280" || "$height" != "720" ]]; then
    # Resizing before the first frame is rendered makes the app give up with
    # "Timed out waiting for OpenGL frame" and exit - llvmpipe is slow enough
    # that the window has to be settled first.
    sleep 6
    DISPLAY="$display" xdotool windowsize "$wid" "$width" "$height"
    sleep 3
  fi
  # Let the UI finish its first paint before anyone captures it.
  sleep 3

  echo "Session ready on $display (window $wid, ${width}x${height})."
  echo "Isolated HOME: $app_home"
}

cmd_shot() {
  local out="${1:?Usage: $0 shot <file.png> [window-id]}"
  local target="${2:-}"
  load_session
  mkdir -p "$(dirname -- "$out")"
  import -window "${target:-$OCPT_WID}" "$out"
  echo "$out"
}

cmd_windows() {
  load_session
  xwininfo -root -children | sed -n '/children:/,$p'
}

cmd_click() {
  local x="${1:?Usage: $0 click <x> <y>}" y="${2:?Usage: $0 click <x> <y>}"
  load_session
  # mousemove then a settled click: Flutter drops press/release pairs that
  # arrive in the same instant as the move.
  xdotool mousemove --window "$OCPT_WID" "$x" "$y" sleep 0.4 click 1 sleep 1
}

# No --window here on purpose: the app's file dialogs are separate X windows, and
# the window manager gives them the focus, so plain XTEST events land wherever
# the user's would. Sending to $OCPT_WID would type into the window behind the
# dialog instead.
cmd_type() {
  local text="${1?Usage: $0 type <text>}"
  load_session
  xdotool type --clearmodifiers --delay 25 -- "$text"
  sleep 0.5
}

cmd_key() {
  local keys="${1:?Usage: $0 key <keys>}"
  load_session
  xdotool key --clearmodifiers "$keys"
  sleep 1
}

# Flutter scrolls whatever is under the pointer, so the pointer has to be moved
# there first: a wheel event delivered to the window alone scrolls nothing. The
# default lands in the middle of the window, which is the content area in every
# mode; pass x and y to aim at a specific panel.
cmd_scroll() {
  local direction="${1:?Usage: $0 scroll <up|down> [n] [x y]}" count="${2:-3}"
  load_session
  local button
  case "$direction" in
    up) button=4 ;;
    down) button=5 ;;
    *) die "scroll takes 'up' or 'down'" ;;
  esac

  local x="${3:-}" y="${4:-}"
  if [[ -z "$x" || -z "$y" ]]; then
    local geometry width height
    geometry=$(xdotool getwindowgeometry --shell "$OCPT_WID")
    width=$(sed -n 's/^WIDTH=//p' <<<"$geometry")
    height=$(sed -n 's/^HEIGHT=//p' <<<"$geometry")
    x=$((width / 2))
    y=$((height / 2))
  fi
  xdotool mousemove --window "$OCPT_WID" "$x" "$y"

  local i
  for i in $(seq 1 "$count"); do
    xdotool click "$button"
  done
  sleep 1
}

cmd_home() { load_session; echo "$OCPT_APP_HOME"; }

cmd_status() {
  load_session
  echo "display: $OCPT_DISPLAY"
  echo "window:  $OCPT_WID"
  echo "home:    $OCPT_APP_HOME"
  xwininfo -id "$OCPT_WID" | grep -E '^\s+(Width|Height):'
}

cmd_stop() {
  [[ -f "$STATE_FILE" ]] || { echo "No session running."; return; }
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  # Kill by recorded pid, never `pkill -f open_cine_prod_tools`: that pattern
  # also matches this script's own command line, so it would kill the caller.
  local pid
  for pid in "$OCPT_APP_PID" "$OCPT_WM_PID" "$OCPT_XVFB_PID"; do
    kill "$pid" 2>/dev/null || true
  done
  rm -f "$STATE_FILE"
  echo "Session stopped."
}

case "${1:-}" in
  start)  shift; cmd_start "$@" ;;
  shot)   shift; cmd_shot "$@" ;;
  click)  shift; cmd_click "$@" ;;
  type)   shift; cmd_type "$@" ;;
  key)    shift; cmd_key "$@" ;;
  scroll) shift; cmd_scroll "$@" ;;
  windows) shift; cmd_windows ;;
  home)   shift; cmd_home ;;
  status) shift; cmd_status ;;
  stop)   shift; cmd_stop ;;
  *)      sed -n '6,47p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
