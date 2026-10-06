#!/usr/bin/env python3
"""Rebuild this handover from existing repository media. No art is generated."""
from pathlib import Path
import hashlib
import html
import json
import shutil
import subprocess
import zipfile
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
COVERS = REPO / "steam/presskit/2026-09-23-cover/exports"
MEDIA = REPO / "steam/store assets/2026-09-20-store-refresh/exports"
LOGO = REPO / "steam/store assets/2026-09-10/upload/library/library_logo_transparent_en.png"
ASSETS = HERE / "assets/auto-shrooms"
PRESS = HERE / "press"
CONTENT = json.loads((HERE / "content.json").read_text())
RECORDS = []


def run(*args):
    return subprocess.check_output([str(a) for a in args], text=True).strip()


def record(path, source, purpose, operation):
    item = {
        "file": str(path.relative_to(HERE)),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "source": str(source.relative_to(REPO)),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "purpose": purpose,
        "operation": operation,
    }
    if path.suffix in (".png", ".jpg", ".webp"):
        width, height = run("magick", "identify", "-format", "%w %h", path).split()
        item.update(width=int(width), height=int(height))
    elif path.suffix == ".mp4":
        item["probe"] = json.loads(run(
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration:stream=codec_name,width,height,avg_frame_rate,pix_fmt",
            "-of", "json", path))
    RECORDS.append(item)


def copy(source, dest, purpose):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    record(dest, source, purpose, "Unmodified file copy")


def webp(source, dest, width, purpose):
    dest.parent.mkdir(parents=True, exist_ok=True)
    run("magick", source, "-resize", f"{width}x>", "-strip", "-quality", "86",
        "-define", "webp:method=6", dest)
    record(dest, source, purpose,
           f"Proportional downscale to {width}px maximum width; WebP quality 86; metadata stripped; no crop or retouch")


def build_media():
    title = COVERS / "auto-shrooms-cover-with-logo-1920x1080.png"
    clean = COVERS / "auto-shrooms-cover-without-logo-1920x1080.png"
    copy(title.with_suffix(".jpg"), ASSETS / "splash-art.jpg", "JPEG fallback and social sharing")
    for width in (640, 960, 1920):
        webp(title, ASSETS / f"splash-art-{width}.webp", width, "Responsive homepage card")
    webp(clean, ASSETS / "cover-clean.webp", 1920, "Optional clean illustration; supply a separate title")
    copy(LOGO, ASSETS / "logo.png", "Transparent wordmark, existing tight export")
    copy(title, PRESS / "auto-shrooms-cover-with-logo.png", "Original 1080p press illustration")
    copy(clean, PRESS / "auto-shrooms-cover-without-logo.png", "Original 1080p clean press illustration")
    for shot in CONTENT["screenshots"]:
        source = MEDIA / "screenshots" / f"{shot['file']}.jpg"
        copy(source, ASSETS / "screenshots" / source.name, "Full-size gameplay screenshot / press download")
        webp(MEDIA / "screenshots" / f"{shot['file']}.png",
             ASSETS / "screenshots" / f"{shot['file']}-960.webp", 960, "Optional gallery thumbnail")
    source = MEDIA / "trailer/auto-shrooms-trailer-32s.mp4"
    copy(source, PRESS / "auto-shrooms-trailer-1080p60.mp4", "Original finished trailer for press / uploads")


def presskit_button(url, label):
    """A blank Dropbox setting is an intentional pending download, never a fake URL."""
    if not url:
        return f'<button class="pk-button pk-button--pending" type="button" disabled>{html.escape(label)}</button>'
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname not in ("dropbox.com", "www.dropbox.com"):
        raise ValueError("links.presskit_dropbox must be an HTTPS Dropbox share URL")
    return f'<a class="pk-button" href="{html.escape(url)}">{html.escape(label)}</a>'


def build_presskit():
    data = json.loads((HERE / "presskit-content.json").read_text())
    render_records = {r["file"]: r for r in json.loads((HERE / "character-renders.json").read_text())}
    character_captions = []
    for character in data["characters"]:
        stem = character["file"]
        image = PRESS / "characters" / f"{stem}.png"
        rendered = render_records[image.name]
        record(image, REPO / character["render"]["source"], "Transparent press character cutout",
               "Godot render of weaponless Child or Adult at idle time 0; default game tints; transparent 768px square; ground shadow hidden; centered with approximately 48px padding")
        RECORDS[-1]["render_recipe"] = "scripts/render_characters.tscn"
        RECORDS[-1]["texture_sources"] = [
            {"file": path, "sha256": hashlib.sha256((REPO / path).read_bytes()).hexdigest()}
            for path in rendered["textures"]
        ]
        character_captions.append(f"- `characters/{stem}.png` — **{character['name']}**: {character['caption']}")
    weapon_captions = []
    for weapon in data["weapons"]:
        source = REPO / weapon["source"]
        dest = PRESS / "weapons" / (weapon["file"] + ".png")
        copy(source, dest, "Standalone transparent weapon sprite for the press download")
        size = RECORDS[-1]
        weapon_captions.append(f"- `weapons/{dest.name}` — **{weapon['name']}** · {size['width']} × {size['height']} PNG")
    fonts = ASSETS / "fonts"
    copy(REPO / "assets/fonts/SpicyRice-Regular.ttf", fonts / "SpicyRice-Regular.ttf", "Exact game title font, self-hosted")
    copy(REPO / "assets/fonts/Fredoka-VariableFont_wdth,wght.ttf", fonts / "Fredoka-Variable.ttf", "Exact game body/UI font, self-hosted")
    webp(REPO / "assets/base/background/bg_nursery.png", ASSETS / "nursery-background.webp", 1920, "Presskit hero backdrop from the game Nursery")
    for filename, family in (("SpicyRice-OFL.txt", "spicyrice"), ("Fredoka-OFL.txt", "fredoka")):
        notice = fonts / filename
        record(notice, notice, "Retained font copyright and license notice", "Official notice retained alongside unmodified game font")
        RECORDS[-1]["source_url"] = f"https://raw.githubusercontent.com/google/fonts/main/ofl/{family}/OFL.txt"
    facts = "\n".join(f"- {f['label']}: {f['value']}" for f in data["facts"])
    features = "\n".join(f"- **{f['title']}:** {f['body']}" for f in data["features"])
    captions = "\n".join(f"- `{s['file']}.jpg` — {s['alt']}" for s in CONTENT["screenshots"])
    fact_text = f'''# Auto Shrooms — press factsheet

Updated {data['updated']}.

{data['one_liner']}

## Facts

{facts}
- Website: {data['links']['website']}
- Steam: {data['links']['steam']}
- Trailer on YouTube: {data['links']['trailer']}
- Press contact: {data['contact']['name']} — {data['contact']['email']}

## Description

{chr(10).join(chr(10) + p for p in data['description'])}

## Features

{features}

## About the studio

{data['studio']}

## Screenshot captions

{captions}

## Characters

{chr(10).join(character_captions)}

Both PNGs have transparent backgrounds on a 768 × 768 canvas. These are weaponless, fixed-pose renders of the Child and Adult with their default in-game colours. Each unit is fitted independently; the files do not represent their relative in-game sizes. Ground shadows are omitted.

## Weapon sprites

{chr(10).join(weapon_captions)}

These {len(data['weapons'])} standalone sprites are unmodified PNG copies of the game's weapon artwork at the original resolution. Combined weapon-and-shield artwork is included alongside the individual weapons. Unit and weapon sprites are supplied in this download only; they are not displayed on the presskit webpage.

## Asset notes

{data['media_notes']}
The clean cover omits the title. The separate logo has a transparent background.
The original trailer is 1920 × 1080, 60 fps, H.264/AAC. Keep its existing end card and attribution when sharing the complete trailer.
Trailer Battle music is credited in-game to Andres D. Bubenhofer.
For additional assets, interviews or usage questions, contact {data['contact']['email']}.
'''
    (PRESS / "FACTSHEET.md").write_text(fact_text)
    archive = HERE / "downloads/auto-shrooms-presskit.zip"
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        files = [(PRESS / "FACTSHEET.md", "FACTSHEET.md"), (ASSETS / "logo.png", "artwork/auto-shrooms-logo.png")]
        files += [(f, "artwork/" + f.name) for f in sorted(PRESS.glob("*.png"))]
        files += [(f, "screenshots/" + f.name) for f in sorted((ASSETS / "screenshots").glob("*.jpg"))]
        files += [(PRESS / "characters" / (c["file"] + ".png"), "characters/" + c["file"] + ".png") for c in data["characters"]]
        files += [(PRESS / "weapons" / (w["file"] + ".png"), "weapons/" + w["file"] + ".png") for w in data["weapons"]]
        files += [(PRESS / "auto-shrooms-trailer-1080p60.mp4", "video/auto-shrooms-trailer-1080p60.mp4")]
        for source, target in files:
            bundle.write(source, Path("auto-shrooms-presskit") / target)
    screenshot_html = []
    for shot in CONTENT["screenshots"]:
        stem = shot["file"]
        screenshot_html.append(f'''<figure><a href="assets/auto-shrooms/screenshots/{stem}.jpg"><img src="assets/auto-shrooms/screenshots/{stem}-960.webp" width="960" height="540" alt="{html.escape(shot['alt'])}" loading="lazy" decoding="async"></a><figcaption>{html.escape(shot['caption'])}</figcaption></figure>''')
    replacements = {
        "ONE_LINER": html.escape(data["one_liner"]), "TAGLINE": html.escape(data["tagline"]),
        "FACTS": "".join(f"<div><dt>{html.escape(f['label'])}</dt><dd>{html.escape(f['value'])}</dd></div>" for f in data["facts"]),
        "UPDATED": html.escape(data["updated"]), "STEAM": html.escape(data["links"]["steam"]),
        "CONTACT_NAME": html.escape(data["contact"]["name"]), "EMAIL": html.escape(data["contact"]["email"]),
        "DESCRIPTION": "".join(f"<p>{html.escape(p)}</p>" for p in data["description"]),
        "FEATURES": "".join(f"<li><h3>{html.escape(f['title'])}</h3><p>{html.escape(f['body'])}</p></li>" for f in data["features"]),
        "SCREENSHOTS": "\n".join(screenshot_html), "STUDIO": html.escape(data["studio"]),
        "WEAPON_COUNT": str(len(data["weapons"])),
        "YOUTUBE_URL": html.escape(data["links"]["trailer"]),
        "YOUTUBE_EMBED": "https://www.youtube.com/embed/" + html.escape(data["youtube_video_id"]),
        "PRESSKIT_HERO_CTA": presskit_button(data["links"]["presskit_dropbox"].strip(), "Download presskit"),
        "PRESSKIT_DOWNLOAD_CTA": presskit_button(data["links"]["presskit_dropbox"].strip(), "Download presskit on Dropbox"),
        "PRESSKIT_DOWNLOAD_STATUS": "Available on Dropbox" if data["links"]["presskit_dropbox"].strip() else "Presskit download coming soon",
    }
    document = (HERE / "templates/presskit.html").read_text()
    for key, value in replacements.items():
        document = document.replace("{{" + key + "}}", value)
    (HERE / "presskit-auto-shrooms.html").write_text(document)


def build_preview():
    card = (HERE / "snippets/game-card.html").read_text().replace('"/assets/', '"assets/')
    card = card.replace(", /assets/", ", assets/")
    card = card.replace('loading="lazy"', 'fetchpriority="high"')
    trailer = (HERE / "snippets/trailer.html").read_text().replace('"/assets/', '"assets/')
    shots = []
    for shot in CONTENT["screenshots"]:
        stem = shot["file"]
        shots.append(f'''<figure>
          <a href="assets/auto-shrooms/screenshots/{stem}.jpg">
            <img src="assets/auto-shrooms/screenshots/{stem}-960.webp" width="960" height="540"
              loading="lazy" decoding="async" alt="{html.escape(shot['alt'])}">
          </a><figcaption>{html.escape(shot['caption'])}</figcaption>
        </figure>''')
    document = '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <title>Auto Shrooms — website handover preview</title>
  <link rel="stylesheet" href="preview/cauldron-games.css">
  <style>
    .preview-heading { margin-bottom: .5rem; }
    .preview-notes { align-self: start; padding: 1rem; }
    .preview-notes h3 { margin-bottom: .5rem; }
    .preview-gallery { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1.5rem; }
    figure { margin: 0; }
    .preview-gallery img { display: block; width: 100%; height: auto; }
    figcaption { margin-top: .5rem; color: var(--ink-muted); font-size: .875rem; }
    .preview-section { margin-top: 2rem; }
    @media (max-width: 52rem) { .preview-gallery { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <a class="skip-link" href="#main-content">Skip to content</a>
  <main id="main-content">
    <p class="eyebrow">Cauldron Games · Website handover · 24 September 2026</p>
    <h1 class="preview-heading">Auto Shrooms</h1>
    <p>Local handover preview using the current cauldron.games stylesheet.</p>
    <section class="content-section" aria-labelledby="games-heading">
      <h2 id="games-heading">Games</h2>
      <div class="game-grid">
        CARD
        <aside class="preview-notes">
          <h3>Placement</h3>
          <p>Add this card before Wageslave in the existing Games grid. Wageslave remains the other card.</p>
          <p>The original site's paper surfaces, blue and gold buttons, typefaces and mobile breakpoint are retained.</p>
          <p><strong>Demo link:</strong> itch.io currently requires a password. This card links to the public Steam page and the supplied trailer.</p>
          <p><a href="HANDOVER.md">Read the handover</a> · <a href="COPY.md">Copy and factsheet</a></p>
          <p><a href="presskit-auto-shrooms.html">Auto Shrooms presskit page</a> · <a href="PRESSKIT-HANDOVER.md">Presskit design guide</a></p>
          <p><a href="assets/auto-shrooms/logo.png">Transparent logo</a> · <a href="press/auto-shrooms-cover-without-logo.png">Clean cover</a></p>
        </aside>
      </div>
    </section>
    <section class="content-section preview-section" aria-labelledby="trailer-heading">
      <h2 id="trailer-heading">Trailer</h2>
      TRAILER
    </section>
    <section class="content-section preview-section" aria-labelledby="gallery-heading">
      <h2 id="gallery-heading">Gameplay screenshots</h2>
      <p>Optional for an Auto Shrooms detail or press page. Select an image for the full-size JPG.</p>
      <div class="preview-gallery">GALLERY</div>
    </section>
  </main>
</body>
</html>
'''
    (HERE / "preview.html").write_text(document.replace("CARD", card).replace("TRAILER", trailer).replace("GALLERY", "\n".join(shots)))


def package():
    (HERE / "asset-manifest.json").write_text(json.dumps({
        "prepared_on": "2026-09-24",
        "paths_relative_to": "handover package root",
        "source_paths_relative_to": "mycelium-prototype repository root",
        "assets": RECORDS,
    }, indent=2) + "\n")
    archive = HERE / "auto-shrooms-website-handover.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(HERE.rglob("*")):
            if path.is_file() and path != archive and (path.suffix != ".zip" or path.parent.name == "downloads") and not any(p.startswith(".") or p == "__pycache__" for p in path.relative_to(HERE).parts):
                bundle.write(path, Path("auto-shrooms-website") / path.relative_to(HERE))
    print(json.dumps({"assets": len(RECORDS),
                      "archive": str(archive), "archive_bytes": archive.stat().st_size}, indent=2))


if __name__ == "__main__":
    build_media()
    build_presskit()
    build_preview()
    package()
