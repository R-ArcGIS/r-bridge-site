"""
Instructions for updating the developer's site repo:
1. Set up machine as specified here: https://docs.afd.geocloud.com/general/install-windows/
2. Clone dev site repo locally; create a new branch; note the repo path and use as DEST_DIR in this script
3. In this script, set `DRY_RUN = True` and run to see which files will be updated (review the log file)
4. If new pages will be added to the documentation site, manually update the yml here: documentation\topic.navigation.yml
5. If new pages will be added to the api ref, manually update the yml here: config\api-ref-topic.navigation.yml
6. If new packages are added to the api ref and need to be added to the drop-down nav, manually update the yml here: config\config.yml
7. In this script, set `DRY_RUN = False` and run it to update the documentation and api-ref files.
8. To preview the site, open cmd prompt as administrator, cd to the dev site repo and run `npm install` (if needed) and `npm start` 
**NOTE** if any changes need to be made, they should be made in the github doc site first and docs should be re-rendered. No doc or api-ref changes should be made directly to the developers site repo!
9. If the site looks good, commit the changes to your new branch and push
10. In the PR, set the branch to merge to "next" (create a next branch based off main if needed) so that the changes can be previewed
11. After a day or so, preview the site at: https://next.gha.afd.arcgis.com/r-bridge/
12. Then create a PR from the next branch to main to push final changes to the live site.
"""

import os
import shutil
import tempfile
import zipfile
import difflib
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


# ----------------------------
# CONFIG
# ----------------------------
SRC_DIR = Path(r"C:\projects\r-bridge-site")
DEST_DIR = Path(r"C:\projects\r-bridge-doc")

ZIP_NAMES = {"_docs.zip", "api-ref.zip"}  # ONLY these are processed

# Ignore these source directory prefixes (relative to extracted root)
IGNORE_PREFIXES = [
    Path(r"_arcgis\docs\auth"),
    Path(r"_arcgis\docs\geocode"),
    Path(r"_arcgis\dev"),
]

# Map extracted source prefixes -> destination prefixes
PATH_MAPPINGS = [
    (Path(r"_arcgis\docs"), Path(r"documentation")),
    (Path(r"_api_ref"), Path(r"api-reference")),
]

# Nav file special-case sync
NAV_SRC = Path(SRC_DIR / r"api-ref\_api_ref\nav.yml")
NAV_DEST = Path(DEST_DIR / r"config\api-ref-topic.navigation.yml")

# Images go here (from extracted _docs.zip content)
IMAGES_DEST_DIR = Path(DEST_DIR / r"documentation\shared\images")

LOG_FILE = SRC_DIR / f"dev/update_devsite_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
DRY_RUN = True


# ----------------------------
# DATA STRUCTURES
# ----------------------------
@dataclass(frozen=True)
class CopyEvent:
    src: Path
    dest: Path
    is_new: bool
    # Diff metadata (used for .md overwrites only)
    has_diff: bool | None = None
    lines_added: int | None = None
    lines_removed: int | None = None


@dataclass(frozen=True)
class NavUpdateResult:
    attempted: bool
    updated: bool
    warning: str | None


# ----------------------------
# HELPERS
# ----------------------------
def _is_under_prefix(rel_path: Path, prefix: Path) -> bool:
    try:
        rel_path.relative_to(prefix)
        return True
    except ValueError:
        return False


def _apply_mappings(rel_path: Path) -> Path:
    for src_prefix, dest_prefix in PATH_MAPPINGS:
        if _is_under_prefix(rel_path, src_prefix):
            return dest_prefix / rel_path.relative_to(src_prefix)
    return rel_path


def _safe_extract(zip_path: Path, extract_to: Path) -> None:
    with zipfile.ZipFile(zip_path, "r") as zf:
        for member in zf.infolist():
            if member.is_dir():
                continue

            member_path = Path(member.filename)
            dest_path = (extract_to / member_path).resolve()

            # zip-slip protection
            if not str(dest_path).startswith(str(extract_to.resolve()) + os.sep):
                raise RuntimeError(f"Blocked zip-slip path: {member.filename}")

            dest_path.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(member, "r") as src_f, open(dest_path, "wb") as dst_f:
                shutil.copyfileobj(src_f, dst_f)


def _collect_files(root: Path) -> list[Path]:
    return [p for p in root.rglob("*") if p.is_file()]


def _should_copy_markdown(src_file: Path) -> bool:
    return src_file.suffix.lower() == ".md"


def _should_copy_html(src_file: Path) -> bool:
    return src_file.suffix.lower() == ".html"


def _read_text_normalized(p: Path) -> str:
    """
    Read as utf-8 (lossy if needed) and normalize newlines so CRLF vs LF
    doesn't register as a huge diff.
    """
    text = p.read_text(encoding="utf-8", errors="replace")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def _line_diff_counts(old_text: str, new_text: str) -> tuple[int, int]:
    """
    Returns (lines_added, lines_removed), treating 'replace' as removed+added.
    """
    old_lines = old_text.splitlines()
    new_lines = new_text.splitlines()

    sm = difflib.SequenceMatcher(a=old_lines, b=new_lines)
    added = removed = 0
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "insert":
            added += (j2 - j1)
        elif tag == "delete":
            removed += (i2 - i1)
        elif tag == "replace":
            removed += (i2 - i1)
            added += (j2 - j1)
    return added, removed


def _copy_file(
    src: Path,
    dest: Path,
    *,
    has_diff: bool | None = None,
    lines_added: int | None = None,
    lines_removed: int | None = None,
) -> CopyEvent:
    existed = dest.exists()
    if not DRY_RUN:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
    return CopyEvent(
        src=src,
        dest=dest,
        is_new=not existed,
        has_diff=has_diff,
        lines_added=lines_added,
        lines_removed=lines_removed,
    )


# ----------------------------
# DOC SYNC FROM ZIPS
#  - For _docs.zip: copy only .md
#  - For api-ref.zip: copy .md + .html (no diff for .html)
# ----------------------------
def sync_markdown_from_extracted_root(extract_root: Path) -> list[CopyEvent]:
    """
    Copies markdown files (.md) only, with diff metadata when overwriting.
    """
    events: list[CopyEvent] = []

    for src_file in _collect_files(extract_root):
        rel = src_file.relative_to(extract_root)

        if src_file.suffix.lower() == ".zip":
            continue

        if not _should_copy_markdown(src_file):
            continue

        # Skip ignored directories
        if any(_is_under_prefix(rel, prefix) for prefix in IGNORE_PREFIXES):
            continue

        mapped_rel = _apply_mappings(rel)
        dest_file = DEST_DIR / mapped_rel

        # Diff check for overwrites
        if dest_file.exists():
            old_text = _read_text_normalized(dest_file)
            new_text = _read_text_normalized(src_file)
            has_diff = (old_text != new_text)
            if has_diff:
                added, removed = _line_diff_counts(old_text, new_text)
            else:
                added, removed = (0, 0)

            events.append(
                _copy_file(
                    src_file,
                    dest_file,
                    has_diff=has_diff,
                    lines_added=added,
                    lines_removed=removed,
                )
            )
        else:
            events.append(_copy_file(src_file, dest_file))

    return events


def sync_html_from_extracted_root_api_ref_only(extract_root: Path) -> list[CopyEvent]:
    """
    Copies HTML files (.html) from api-ref.zip extraction only.
    No diff metadata.
    """
    events: list[CopyEvent] = []

    for src_file in _collect_files(extract_root):
        rel = src_file.relative_to(extract_root)

        if src_file.suffix.lower() == ".zip":
            continue

        if not _should_copy_html(src_file):
            continue

        # Ignore prefixes are mainly for docs; safe to keep consistent.
        if any(_is_under_prefix(rel, prefix) for prefix in IGNORE_PREFIXES):
            continue

        mapped_rel = _apply_mappings(rel)
        dest_file = DEST_DIR / mapped_rel

        events.append(_copy_file(src_file, dest_file))

    return events


# ----------------------------
# IMAGE SYNC (FROM UNZIPPED _DOCS CONTENT)
# Copy ONLY NEW images from extracted "_arcgis/images" -> documentation/shared/images
# ----------------------------
def sync_new_images_from_extracted_docs(extract_root: Path) -> list[CopyEvent]:
    events: list[CopyEvent] = []

    candidate_rel_paths = [
        Path(r"_docs\_arcgis\images"),
        Path(r"_arcgis\images"),
    ]

    images_root = None
    for cand in candidate_rel_paths:
        p = extract_root / cand
        if p.exists() and p.is_dir():
            images_root = p
            break

    if images_root is None:
        return events

    for src_img in images_root.rglob("*"):
        if not src_img.is_file():
            continue
        if src_img.suffix.lower() == ".zip":
            continue

        rel = src_img.relative_to(images_root)
        dest_img = IMAGES_DEST_DIR / rel

        # Copy only new images
        if dest_img.exists():
            continue

        events.append(_copy_file(src_img, dest_img))

    return events


# ----------------------------
# NAV FILE UPDATE (SPECIAL CASE)
# ----------------------------
def update_nav_file() -> NavUpdateResult:
    if not NAV_SRC.exists():
        return NavUpdateResult(
            attempted=False,
            updated=False,
            warning=f"NAV SOURCE MISSING: {NAV_SRC}",
        )

    src_text = NAV_SRC.read_text(encoding="utf-8")
    src_lines = src_text.splitlines()

    if not NAV_DEST.exists():
        NAV_DEST.parent.mkdir(parents=True, exist_ok=True)
        if not DRY_RUN:
            NAV_DEST.write_text(src_text, encoding="utf-8")
        return NavUpdateResult(attempted=True, updated=True, warning=None)

    dest_text = NAV_DEST.read_text(encoding="utf-8")
    dest_lines = dest_text.splitlines()

    if len(dest_lines) > len(src_lines):
        return NavUpdateResult(
            attempted=True,
            updated=False,
            warning=(
                "NAV NOT OVERWRITTEN: destination has more lines than source "
                f"({len(dest_lines)} > {len(src_lines)}). "
                "Destination may contain additional content not present in source."
            ),
        )

    if not DRY_RUN:
        NAV_DEST.write_text(src_text, encoding="utf-8")
    return NavUpdateResult(attempted=True, updated=True, warning=None)


# ----------------------------
# LOGGING
# ----------------------------
def write_log(
    md_events: list[CopyEvent],
    html_events: list[CopyEvent],
    image_events: list[CopyEvent],
    processed_zips: list[Path],
    nav_result: NavUpdateResult,
) -> None:
    md_overwrites = [e for e in md_events if not e.is_new]
    md_new = [e for e in md_events if e.is_new]

    md_overwrites_no_diff = [e for e in md_overwrites if e.has_diff is False]
    md_overwrites_diff = [e for e in md_overwrites if e.has_diff is True]
    md_overwrites_unknown = [e for e in md_overwrites if e.has_diff is None]

    html_overwrites = [e for e in html_events if not e.is_new]
    html_new = [e for e in html_events if e.is_new]

    lines: list[str] = []
    lines.append("DOC SYNC LOG")
    lines.append("=" * 80)
    lines.append(f"Timestamp: {datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"Source repo: {SRC_DIR}")
    lines.append(f"Destination repo: {DEST_DIR}")
    lines.append(f"Dry run: {DRY_RUN}")
    lines.append("")

    lines.append("Processed zip files:")
    if processed_zips:
        for z in processed_zips:
            lines.append(f"  - {z}")
    else:
        lines.append("  (none found)")
    lines.append("")

    lines.append("NAV FILE UPDATE")
    lines.append("-" * 80)
    lines.append(f"Source:      {NAV_SRC}")
    lines.append(f"Destination: {NAV_DEST}")
    if not nav_result.attempted:
        lines.append("Status:      SKIPPED")
        if nav_result.warning:
            lines.append(f"Warning:     {nav_result.warning}")
    else:
        lines.append(f"Status:      {'UPDATED' if nav_result.updated else 'NOT UPDATED'}")
        if nav_result.warning:
            lines.append(f"Warning:     {nav_result.warning}")
    lines.append("")

    lines.append("OVERWRITTEN MARKDOWN FILES (.md) - NO DIFF")
    lines.append("-" * 80)
    if md_overwrites_no_diff:
        for e in md_overwrites_no_diff:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")
    else:
        lines.append("(none)\n")

    lines.append("OVERWRITTEN MARKDOWN FILES (.md) - DIFF")
    lines.append("-" * 80)
    if md_overwrites_diff:
        for e in md_overwrites_diff:
            lines.append(f"SRC:           {e.src}")
            lines.append(f"DEST:          {e.dest}")
            lines.append(f"LINES_ADDED:   {e.lines_added}")
            lines.append(f"LINES_REMOVED: {e.lines_removed}")
            lines.append("")
    else:
        lines.append("(none)\n")

    if md_overwrites_unknown:
        lines.append("OVERWRITTEN MARKDOWN FILES (.md) - (NO DIFF INFO)")
        lines.append("-" * 80)
        for e in md_overwrites_unknown:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")

    lines.append("NEW MARKDOWN FILES ADDED (.md)")
    lines.append("-" * 80)
    if md_new:
        for e in md_new:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")
    else:
        lines.append("(none)\n")

    # New: HTML log sections for api-ref.zip
    lines.append("OVERWRITTEN API REF HTML FILES (.html)")
    lines.append("-" * 80)
    if html_overwrites:
        for e in html_overwrites:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")
    else:
        lines.append("(none)\n")

    lines.append("NEW API REF HTML FILES ADDED (.html)")
    lines.append("-" * 80)
    if html_new:
        for e in html_new:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")
    else:
        lines.append("(none)\n")

    lines.append("NEW IMAGES ADDED (from extracted _docs.zip)")
    lines.append("-" * 80)
    lines.append(f"Images destination: {IMAGES_DEST_DIR}")
    if image_events:
        for e in image_events:
            lines.append(f"SRC:  {e.src}")
            lines.append(f"DEST: {e.dest}")
            lines.append("")
    else:
        lines.append("(none)\n")

    LOG_FILE.write_text("\n".join(lines), encoding="utf-8")


# ----------------------------
# ENTRY POINT
# ----------------------------
def main() -> None:
    processed_zips: list[Path] = []
    md_events: list[CopyEvent] = []
    html_events: list[CopyEvent] = []
    image_events: list[CopyEvent] = []

    for zip_name in sorted(ZIP_NAMES):
        zip_path = SRC_DIR / zip_name
        if not zip_path.exists():
            continue

        processed_zips.append(zip_path)

        with tempfile.TemporaryDirectory(prefix=f"extract_{zip_path.stem}_") as td:
            extract_root = Path(td)
            _safe_extract(zip_path, extract_root)

            # Markdown sync for BOTH zips
            md_events.extend(sync_markdown_from_extracted_root(extract_root))

            # HTML sync ONLY for api-ref.zip
            if zip_name == "api-ref.zip":
                html_events.extend(sync_html_from_extracted_root_api_ref_only(extract_root))

            # Image sync ONLY from _docs.zip extraction
            if zip_name == "_docs.zip":
                image_events.extend(sync_new_images_from_extracted_docs(extract_root))

    nav_result = update_nav_file()

    write_log(md_events, html_events, image_events, processed_zips, nav_result)

    print(f"Wrote log: {LOG_FILE}")
    print(f"Markdown overwritten: {sum(1 for e in md_events if (not e.is_new and e.dest.exists()))}")
    print(f"Markdown new:        {sum(1 for e in md_events if e.is_new)}")
    print(f"HTML overwritten:    {sum(1 for e in html_events if not e.is_new)}")
    print(f"HTML new:           {sum(1 for e in html_events if e.is_new)}")
    print(f"Images new:         {len(image_events)}")
    if nav_result.attempted:
        print(f"Nav updated:         {nav_result.updated}")
    else:
        print("Nav updated:         (skipped)")


if __name__ == "__main__":
    main()