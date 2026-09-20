# Auto Shrooms — portrait social trailer

The social version follows the approved 32-second trailer: battle hook, original Plant & Harvest, Training, Formation changes, battle montage, and a five-second wishlist card. The extended gardening and lineage description loops are not in this cut.

## Files

| File | Purpose |
| --- | --- |
| `exports/social/auto-shrooms-reel-32s-1080x1920.mp4` | Upload to Reels, TikTok, or Shorts |
| `exports/social/auto-shrooms-reel-cover-1080x1920.jpg` | Optional cover, taken from the portrait end card |
| `sources/masters/auto-shrooms-reel-32s-lossless.mov` | Lossless RGB PNG / PCM editing master |
| `scripts/portrait-edit.json` | Individual shot ranges, crops, captions, and transitions |
| `scripts/render_portrait.py` | Reproducible portrait composition and export |
| `social-validation.json` | File, timeline, audio, and layout checks |
| `auto-shrooms-social-reel.zip` | MP4, cover, and this guide |

Revision 2 replaces the Training footage in step with landscape revision 8: a Sword Child previews a Great Sword, then the player confirms. The standalone Training loop is updated too; the other four description loops retain their edits. The Steam upload ZIP excludes the social files.

## Official specifications checked September 20, 2026

| Platform / official source | Relevant specifications | Chosen export |
| --- | --- | --- |
| [Meta Instagram Reels publishing sample](https://github.com/fbsamples/reels_publishing_apis/blob/main/insta_reels_publishing_api_sample/README.md#reels-requirements-for-publishing) | Recommends 9:16. MP4/MOV; H.264/HEVC, progressive, closed GOP, 4:2:0; 23–60 fps; width ≤1920; VBR ≤25 Mbps; AAC ≤48 kHz, 128 kbps; 3 seconds–15 minutes; ≤1 GB. Fast-start MP4 without edit lists. | 1080×1920, 60 fps, 32 seconds; H.264 High, closed GOP; 20 Mbps VBV ceiling; AAC stereo, 48 kHz, 128 kbps; fast start, no edit lists. |
| [TikTok In-Feed specifications](https://ads.tiktok.com/resources/help/article/tiktok-auction-in-feed-ads?lang=en) | Official advertising guidance recommends vertical 9:16, at least 540×960. MP4 accepted; non-Spark files ≤500 MB, bitrate ≥516 kbps. Safe zones depend on captions and placement. | 9:16 at 1080×1920, MP4; size and bitrate checked. Used as a technical compatibility baseline, not a statement of organic-post limits. |
| [YouTube Shorts eligibility](https://support.google.com/youtube/answer/15424877?hl=en) and [upload encoding guidance](https://support.google.com/youtube/answer/1722171?hl=en) | Square/vertical videos up to three minutes qualify as Shorts. Guidance supports H.264 MP4, progressive scan, 4:2:0, the captured frame rate, 48 kHz audio, and BT.709 SDR. | Vertical 32-second video, native 60 fps, H.264, BT.709, AAC. The common export uses Meta's 128 kbps audio setting; YouTube recommends a higher stereo audio bitrate. |

Meta's consumer Help and Ads Guide pages returned a login/block page during research. The accessible Meta-owned `fbsamples` repository above supplied the publishing specifications. Its API requirements are distinguished here from paid-ad recommendations. No third-party sizing guide was used as authority.

## Portrait edit and interface clearance

Gameplay is reframed shot by shot from the native 2560×1440 lossless takes. Most shots use a large square crop so Units, Plots, and the Training confirmation remain readable. Brief wider shots establish army scale and the Training drag. All crops preserve image proportions. Existing capsule artwork supplies the subdued full-height background.

Paper action captions sit near the lower left of the gameplay. The end card is composed specifically for portrait: capsule, “Fungus Vult!”, official Steam logo, and Fredoka wishlist CTA. Key text and end-card elements are kept inside the editorial region **x=80–900, y=270–1248** on the 1080×1920 canvas. This reserves extra room for the right-side controls and lower caption/button area. These conservative production margins are not a platform-guaranteed safe zone; TikTok explicitly notes that overlays vary with caption length and placement. Use the native post preview to check the chosen caption and cover crop.

The music and SFX mix is copied from the current lossless landscape master, including the new Training confirmation sounds. Cuts, transitions, the five-second end card, and the 2.8-second music fade keep their original timing. No extra gameplay sequences, synthetic gameplay, or speed changes were added.

## Rebuild

From the full package directory:

```sh
python3 scripts/render_portrait.py --preview
python3 scripts/render_portrait.py
python3 scripts/validate_portrait.py
python3 scripts/package_social.py
```

To replace a shot, edit `scripts/portrait-edit.json`, then render only the affected chapter with `python3 scripts/render_portrait.py --chapters 03-train`. If the landscape soundtrack changes, rebuild the landscape master first. The original lossless takes, graphics, fonts, and landscape soundtrack master remain required. Preview contact sheets are in `preview/portrait/`; the current Training and ending review is `preview/sword-child/portrait-final-contact.jpg`.

## Verification

The final MP4 is 23.60 MB, 1080×1920 with 1920 picture frames at 60 fps. Its video bitrate is 5.76 Mbps, with 128 kbps AAC. Container duration is 32.033 seconds because of encoder timestamps; the picture edit remains 32 seconds. Full decoding, fast-start layout, absence of edit lists, source crop bounds, caption/CTA margins, and the quiet tail passed checks. The portrait master’s PCM soundtrack is identical to the approved landscape master.

Final phone-size frames and the portrait end card were visually checked. Audio measures -16.2 LUFS integrated and -1.2 dBFS true peak. Both trailers use identical new Training source ranges, and the portrait PCM soundtrack matches the updated landscape master exactly.
