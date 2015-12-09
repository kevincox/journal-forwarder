#!/bin/bash

set -eE

debug="$JF_DEBUG"
unset JF_DEBUG

[ -z "$debug" ] && url="${JF_URL:-$(cat "$JF_URL_SRC")}"
unset JF_URL
unset JF_URL_SRC

cursor_loc="${JF_CURSOR:-journal-forward.cursor}"
unset JF_CURSOR

batch="${JF_BATCH:-100}"
unset JF_BATCH

set_cursor() {
	cursor="$(journalctl "$@" -qn0 --show-cursor | \
		sed -ne 's/^-- cursor: \(.*\)/\1/ p')"
}

save_cursor() {
	echo "$cursor" > "$cursor_loc.tmp"
	mv "$cursor_loc.tmp" "$cursor_loc"
}

send() {
	cursor="$(tail -n1 <<<"$1" | jq -r '.__CURSOR')"
	if [ -z "$debug" ]; then
		curl -sSfX POST -T - "$url" <<<"$1"
	else
		echo "LOG: $1"
	fi
	save_cursor
}

if [ \! -r sumologic.cursor ]; then
	echo "This appears to be the first run, going back 1 day."
	set_cursor --since=-1day
else
	cursor="$(cat sumologic.cursor)"
	if !(journalctl -q "$cursor" -n0); then
		echo "Error: Saved cursor '$cursor' invalid."
		echo 'Falling back to current time, may have missed messages.'
		set_cursor
	fi
fi

echo "Starting with cursor '$cursor'"
while true; do
	lines="$(journalctl -q --after-cursor "$cursor" "-n$batch" -ojson)"
	
	if [ ${#lines} -ne 0 ]; then
		send "$lines"
	else
		break
	fi
done

echo 'Backlog consumed, transmitting logs live.'
journalctl --after-cursor "$cursor" -qfojson | while read -r line; do
	send "$line"
done
