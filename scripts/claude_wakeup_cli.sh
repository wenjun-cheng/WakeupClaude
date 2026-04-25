#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${WAKEUP_ROOT:-/home/wjchengx/projects/wakeup_claude}"
LOG_DIR="${WAKEUP_LOG_DIR:-$ROOT_DIR/logs}"
JSON_LOG="${WAKEUP_JSON_LOG:-$LOG_DIR/cli-wakeup.jsonl}"
TEXT_LOG="${WAKEUP_TEXT_LOG:-$LOG_DIR/cli-wakeup.log}"
ERR_LOG="${WAKEUP_ERR_LOG:-$LOG_DIR/cli-wakeup.err.log}"

MODEL="${WAKEUP_MODEL:-haiku}"
EFFORT="${WAKEUP_EFFORT:-low}"
PROMPT="${WAKEUP_PROMPT:-1}"
SYSTEM_PROMPT="${WAKEUP_SYSTEM_PROMPT:-Return exactly: 1}"
TIMEOUT_SECONDS="${WAKEUP_TIMEOUT_SECONDS:-60}"

mkdir -p "$LOG_DIR"
cd "$ROOT_DIR"

raw_output=""
exit_code=0

set +e
raw_output=$(
  /usr/bin/timeout "${TIMEOUT_SECONDS}s" \
    /usr/bin/npx -y @anthropic-ai/claude-code \
      -p "$PROMPT" \
            --no-chrome \
      --dangerously-skip-permissions \
      --tools "" \
      --system-prompt "$SYSTEM_PROMPT" \
      --no-session-persistence \
      --output-format json \
      --effort "$EFFORT" \
      --model "$MODEL" \
    2>>"$ERR_LOG"
)
exit_code=$?
set -e

RAW_OUTPUT="$raw_output" python3 - "$JSON_LOG" "$TEXT_LOG" "$MODEL" "$EFFORT" "$exit_code" <<'PY'
import datetime
import json
import os
import sys

json_log = sys.argv[1]
text_log = sys.argv[2]
model = sys.argv[3]
effort = sys.argv[4]
exit_code = int(sys.argv[5])
raw = os.environ.get("RAW_OUTPUT", "").strip()

now = datetime.datetime.now(datetime.timezone.utc).isoformat()
entry = {
    "ts": now,
    "exit_code": exit_code,
    "ok": exit_code == 0,
    "model": model,
    "effort": effort,
    "prompt": "1",
    "response": "",
    "subtype": "",
    "parse_error": "",
    "raw_excerpt": raw[:200],
    "usage": {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read_input_tokens": 0,
        "cache_creation_input_tokens": 0,
        "total_tokens": 0,
    },
}

if raw:
    try:
        parsed = json.loads(raw)
        entry["response"] = str(parsed.get("result", "")).strip()
        entry["subtype"] = str(parsed.get("subtype", ""))
        usage = parsed.get("usage") or {}
        input_tokens = int(usage.get("input_tokens", 0) or 0)
        output_tokens = int(usage.get("output_tokens", 0) or 0)
        cache_read = int(usage.get("cache_read_input_tokens", 0) or 0)
        cache_create = int(usage.get("cache_creation_input_tokens", 0) or 0)

        if (input_tokens + output_tokens + cache_read + cache_create) == 0:
            # Some builds expose usage only in modelUsage.* camelCase fields.
            model_usage = parsed.get("modelUsage") or {}
            aggregate = {
                "inputTokens": 0,
                "outputTokens": 0,
                "cacheReadInputTokens": 0,
                "cacheCreationInputTokens": 0,
            }
            for value in model_usage.values():
                if not isinstance(value, dict):
                    continue
                aggregate["inputTokens"] += int(value.get("inputTokens", 0) or 0)
                aggregate["outputTokens"] += int(value.get("outputTokens", 0) or 0)
                aggregate["cacheReadInputTokens"] += int(
                    value.get("cacheReadInputTokens", 0) or 0
                )
                aggregate["cacheCreationInputTokens"] += int(
                    value.get("cacheCreationInputTokens", 0) or 0
                )

            input_tokens = aggregate["inputTokens"]
            output_tokens = aggregate["outputTokens"]
            cache_read = aggregate["cacheReadInputTokens"]
            cache_create = aggregate["cacheCreationInputTokens"]

        entry["usage"] = {
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cache_read_input_tokens": cache_read,
            "cache_creation_input_tokens": cache_create,
            "total_tokens": input_tokens + output_tokens + cache_read + cache_create,
        }
    except Exception:
        entry["parse_error"] = "invalid_json"
        entry["response"] = raw[:400]
else:
    entry["parse_error"] = "empty_output"

with open(json_log, "a", encoding="utf-8") as jf:
    jf.write(json.dumps(entry, ensure_ascii=True) + "\n")

with open(text_log, "a", encoding="utf-8") as tf:
    tf.write(
        f"[{now}] "
        f"ok={entry['ok']} "
        f"subtype={entry['subtype']} "
        f"model={model} "
        f"effort={effort} "
        f"total_tokens={entry['usage']['total_tokens']} "
        f"response={entry['response']}\n"
    )
PY

exit "$exit_code"
