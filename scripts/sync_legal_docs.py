#!/usr/bin/env python3
"""Strip [[REVIEW]] markers and apply bulk legal text fixes."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / "store/legal"
ASSETS = ROOT / "assets/legal"

EFFECTIVE = "2026년 9월 1일"
REVIEW = re.compile(r"\[\[REVIEW:[^\]]*\]\]([\s\S]*?)\[\[/REVIEW\]\]")


def strip(text: str) -> str:
    return REVIEW.sub(r"\1", text)


def clean(text: str) -> str:
    text = strip(text)
    text = text.replace("2026년 ○월 ○일", EFFECTIVE)
    text = re.sub(
        r"※ 노란[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 본 문서는[^\n]*법무 검토[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 본 문서는[^\n]*KISA[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 알바몬[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 토스페이먼츠[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 위치정보법[^\n]*\n",
        "",
        text,
    )
    text = re.sub(
        r"※ 사람인[^\n]*\n",
        "",
        text,
    )
    return text


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    for path in sorted(LEGAL.glob("*.md")):
        raw = path.read_text(encoding="utf-8")
        if path.name in {"05_paid_service_refund.md", "07_outsourcing_restrictions.md"}:
            out = raw  # already final
        else:
            out = clean(raw)
        path.write_text(out, encoding="utf-8")
        (ASSETS / path.name).write_text(out, encoding="utf-8")
        print(f"ok {path.name}")


if __name__ == "__main__":
    main()
