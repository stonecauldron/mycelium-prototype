#!/usr/bin/env python3
"""Check the actual desktop SDK's resource setters, without credentials or events."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument(
        "--sdk", type=Path,
        default=Path(__file__).resolve().parents[1] / "addons/GameAnalytics",
    )
    args = parser.parse_args()
    platform = {"darwin": "macos", "win32": "windows", "linux": "linux"}.get(sys.platform)
    if platform is None:
        parser.error("Run this check on macOS, Windows, or Linux.")

    with tempfile.TemporaryDirectory(prefix="gameanalytics-sdk-check-") as directory:
        project = Path(directory)
        addon = project / "addons/GameAnalytics"
        shutil.copytree(args.sdk / "bin" / platform, addon / "bin" / platform)
        shutil.copy2(args.sdk / "GameAnalytics.gdextension", addon)
        # Godot loads CORE-level extensions at startup from its extension list.
        # Seed that list so this small fixture needs no editor/import pass.
        (project / ".godot").mkdir()
        (project / ".godot/extension_list.cfg").write_text(
            "res://addons/GameAnalytics/GameAnalytics.gdextension\n"
        )
        (project / "project.godot").write_text(
            'config_version=5\n[application]\n'
            'config/name="GameAnalytics SDK check"\n'
            'run/main_scene="res://check.tscn"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        )
        (project / "check.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://check.gd" id="1"]\n'
            '[node name="Check" type="Node"]\nscript = ExtResource("1")\n'
        )
        (project / "check.gd").write_text(
            'extends Node\n'
            'func _ready() -> void:\n'
            '\tif not Engine.has_singleton("GameAnalytics"):\n'
            '\t\tget_tree().quit(1)\n\t\treturn\n'
            '\tvar ga: Object = Engine.get_singleton("GameAnalytics")\n'
            '\tga.setEnabledInfoLog(true)\n'
            '\tga.configureAvailableResourceCurrencies(["Biomass"])\n'
            '\tga.configureAvailableResourceItemTypes(["Start", "Scout"])\n'
            '\tawait get_tree().create_timer(1.0).timeout\n'
            '\tget_tree().quit()\n'
        )
        result = subprocess.run(
            [args.godot, "--headless", "--path", str(project)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30,
        )

    expected = (
        "Set available resource currencies: (Biomass)",
        "Set available resource item types: (Start, Scout)",
    )
    wrong_setter = "Set available resource currencies: (Start, Scout)"
    if result.returncode != 0 or any(line not in result.stdout for line in expected) or wrong_setter in result.stdout:
        print("FAIL: GameAnalytics resource configuration did not reach the correct setters.")
        print(result.stdout)
        return 1
    print("PASS: currency and item-type configuration reach separate native SDK setters.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
