#!/usr/bin/env python3
"""Package delivery exports, copy, and guide. Keep lossless sources in the full folder."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
PACKAGE = Path(__file__).resolve().parents[1]
output = PACKAGE / 'auto-shrooms-steam-upload.zip'
files = [p for folder in ['trailer', 'loops', 'screenshots', 'headers']
         for p in sorted((PACKAGE / 'exports' / folder).rglob('*'))]
files += [PACKAGE / 'README.md', PACKAGE / 'STORE-COPY.md', PACKAGE / 'HEADER-GUIDE.md']
with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
    for path in files:
        if path.is_file():
            archive.write(path, path.relative_to(PACKAGE))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    print(f'{len(archive.namelist())} verified files, {output.stat().st_size / 1e6:.1f} MB')
