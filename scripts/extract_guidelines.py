"""Create a readable Markdown transcript from the supplied guidelines DOCX."""
from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "guidelines" / "Terminal Bench 2.1 - Guidelines.docx"
OUTPUT = ROOT / "guidelines" / "guidelines-extracted-text.md"


def blocks(document: Document):
    for child in document.element.body.iterchildren():
        if child.tag.endswith("}p"):
            yield Paragraph(child, document)
        elif child.tag.endswith("}tbl"):
            yield Table(child, document)


def main() -> None:
    document = Document(SOURCE)
    lines = [
        "# Terminal-Bench 2.1 task-authoring guidelines",
        "",
        "> Readable transcript of the supplied DOCX. The DOCX remains the source of truth.",
        "",
    ]
    for block in blocks(document):
        if isinstance(block, Paragraph):
            text = block.text.strip()
            if text:
                lines.extend((text, ""))
            continue
        rows = [[cell.text.strip().replace("\n", " ") for cell in row.cells] for row in block.rows]
        if not rows:
            continue
        width = max(len(row) for row in rows)
        rows = [row + [""] * (width - len(row)) for row in rows]
        lines.append("| " + " | ".join(rows[0]) + " |")
        lines.append("| " + " | ".join("---" for _ in range(width)) + " |")
        for row in rows[1:]:
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")
    OUTPUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
