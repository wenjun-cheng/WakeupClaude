#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Show wake-up token usage entries")
    parser.add_argument(
        "--log-file",
        default="logs/cli-wakeup.jsonl",
        help="JSONL token log file",
    )
    parser.add_argument(
        "--day",
        default=dt.date.today().isoformat(),
        help="Day to summarize in local date format YYYY-MM-DD",
    )
    parser.add_argument(
        "--last",
        type=int,
        default=12,
        help="How many recent entries to print",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Show daily totals summary before recent entries",
    )
    return parser.parse_args()


def load_entries(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def day_of(entry: dict) -> str:
    ts = str(entry.get("ts", ""))
    if not ts:
        return ""
    return ts[:10]


def main() -> int:
    args = parse_args()
    log_path = Path(args.log_file)
    rows = load_entries(log_path)
    daily = [r for r in rows if day_of(r) == args.day]

    def sum_key(key: str) -> int:
        return sum(int((r.get("usage") or {}).get(key, 0) or 0) for r in daily)

    if args.summary:
        ok_count = sum(1 for r in daily if r.get("ok") is True)
        fail_count = len(daily) - ok_count
        print(f"day={args.day} runs={len(daily)} ok={ok_count} fail={fail_count}")
        print(f"input_tokens={sum_key('input_tokens')}")
        print(f"output_tokens={sum_key('output_tokens')}")
        print(f"cache_read_input_tokens={sum_key('cache_read_input_tokens')}")
        print(f"cache_creation_input_tokens={sum_key('cache_creation_input_tokens')}")
        print(f"total_tokens={sum_key('total_tokens')}")

    tail = daily[-max(args.last, 0) :]
    if tail:
        print("recent_entries:")
        for row in tail:
            usage = row.get("usage") or {}
            print(
                "- "
                f"ts={row.get('ts')} "
                f"ok={row.get('ok')} "
                f"used_tokens={usage.get('total_tokens', 0)}"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
