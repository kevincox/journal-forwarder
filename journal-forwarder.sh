#!/bin/bash

set -eE

debug="$JF_DEBUG"
unset JF_DEBUG

[ -z "$debug" ] && url="${JF_URL:-$(cat "$JF_URL_SRC")}"
unset JF_URL
unset JF_URL_SRC

cursor_loc="${JF_CURSOR:-journal-forwarder.cursor}"
unset JF_CURSOR

batch="${JF_BATCH:-100}"
unset JF_BATCH

method="${JF_METHOD:-POST}"
unset JF_METHOD

filter="${JF_FILTER:-.}"
unset JF_FILTER

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
	jq -c "$filter" <<<"$1" | if [ -z "$debug" ]; then
		curl "-sSfX$method" -HContent-Type:application/json -T - "$url" -o/dev/null
	else
		cat
	fi
	save_cursor
}

if [ \! -r "$cursor_loc" ]; then
	logger --journald <<-END
		MESSAGE_ID=f2e153ec33cc4037a9ca1a4180a598de
		SYSLOG_IDENTIFIER=journal-forwarder
		PRIORITY=5
		MESSAGE=This appears to be the first run, going back 1 day.
	END
	set_cursor '-S 1 day ago'
else
	cursor="$(cat "$cursor_loc")"
	if !(journalctl -q "-c$cursor" -n0); then
		logger --journald <<-END
			MESSAGE_ID=75a7247ca3324431b039a3d66ca39543
			SYSLOG_IDENTIFIER=journal-forwarder
			PRIORITY=3
			INVALID_CURSOR=$cursor
			MESSAGE=Invalid cursor. Falling back to current time, messages may be missed.
			JOURNALD_RETURNED=$?
		END
		set_cursor
	fi
fi

logger --journald <<-END
	MESSAGE_ID=4f56c3e133bc411383d7200165e2e866
	SYSLOG_IDENTIFIER=journal-forwarder
	PRIORITY=6
	START_CURSOR=$cursor
	MESSAGE=Starting with cursor '$cursor'
END
while true; do
	lines="$(journalctl -q --after-cursor "$cursor" "-n$batch" -ojson)"
	
	if [ ${#lines} -ne 0 ]; then
		send "$lines"
	else
		break
	fi
done

logger --journald <<-END
	MESSAGE_ID=99a08cb1f53c4f51977dee49456fa507
	SYSLOG_IDENTIFIER=journal-forwarder
	PRIORITY=6
	MESSAGE=Backlog consumed, transmitting logs live.
END
journalctl --after-cursor "$cursor" -qfojson | while read -r line; do
	send "$line"
done
