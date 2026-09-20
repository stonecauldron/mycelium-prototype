#!/usr/bin/env python3
"""Bundle social uploads separately from the Steam deliverables."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

PACKAGE = Path(__file__).resolve().parents[1]
files = sorted((PACKAGE / "exports/social").glob("*"))
files += [PACKAGE / "SOCIAL-REEL.md", PACKAGE / "social-validation.json"]
output = PACKAGE / "auto-shrooms-social-reel.zip"
with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=6) as archive:
    for path in files:
        if path.is_file():
            archive.write(path, path.relative_to(PACKAGE))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    print(f"{len(archive.namelist())} verified files, {output.stat().st_size / 1e6:.1f} MB")
