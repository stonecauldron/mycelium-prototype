"""Add the same AnimationPlayer-driven frame setup used by the mushrooms."""
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def track(index, path, times, values):
    return f'''tracks/{index}/type = "value"
tracks/{index}/imported = false
tracks/{index}/enabled = true
tracks/{index}/path = NodePath("{path}")
tracks/{index}/interp = 0
tracks/{index}/loop_wrap = true
tracks/{index}/keys = {{
"times": PackedFloat32Array({times}),
"transitions": PackedFloat32Array({', '.join('1' for _ in values)}),
"update": 1,
"values": [{', '.join(values)}]
}}
'''


for enemy in ['stump', 'durian', 'log', 'acorn_knight']:
    folder = ROOT / f'assets/units/enemies/{enemy}'
    scene_path = folder / f'{enemy}_appearance.tscn'
    scene = scene_path.read_text()
    assert 'WalkFrames' not in scene, 'Already wired'
    source = Image.open(folder / f'{enemy}.png')
    original = source.getbbox()
    sheet = Image.open(folder / f'{enemy}_walk.png')
    boxes = []
    for row in range(2):
        for col in range(2):
            cell = sheet.crop((col * 627, row * 627, (col + 1) * 627, (row + 1) * 627))
            boxes.append(cell.getchannel('A').point(lambda p: 255 if p > 10 else 0).getbbox())
    width = max(b[2] - b[0] for b in boxes)
    height = max(b[3] - b[1] for b in boxes)
    resources = f'[ext_resource type="Texture2D" path="res://assets/units/enemies/{enemy}/{enemy}_walk.png" id="4_walk"]\n\n'
    for index, box in enumerate(boxes):
        x = round((box[0] + box[2] - width - 2) / 2) + (index % 2) * 627
        y = box[1] - 1 + (index // 2) * 627
        assert x >= 0 and y >= 0 and x + width + 2 <= sheet.width and y + height + 2 <= sheet.height
        resources += f'''[sub_resource type="AtlasTexture" id="AtlasTexture_walk_{index}"]
atlas = ExtResource("4_walk")
region = Rect2({x}, {y}, {width + 2}, {height + 2})

'''
    resources += '''[sub_resource type="SpriteFrames" id="SpriteFrames_walk"]
animations = [{
"frames": [''' + ', '.join(f'''{{
"duration": 1.0,
"texture": SubResource("AtlasTexture_walk_{index}")
}}''' for index in range(4)) + '''],
"loop": true,
"name": &"walk",
"speed": 5.5555553
}]

'''
    scene = scene.replace('[sub_resource type="Animation" id="Animation_idle"]', resources + '[sub_resource type="Animation" id="Animation_idle"]', 1)
    idle_tracks = track(1, 'Sprite:self_modulate', '0', ['Color(1, 1, 1, 1)'])
    idle_tracks += track(2, 'Sprite/WalkFrames:visible', '0', ['false'])
    idle_tracks += track(3, 'Sprite/WalkFrames:frame', '0', ['0'])
    scene = scene.replace('\n[sub_resource type="Animation" id="Animation_walk"]', '\n' + idle_tracks + '\n[sub_resource type="Animation" id="Animation_walk"]', 1)
    start = scene.index('[sub_resource type="Animation" id="Animation_walk"]')
    end = scene.index('[sub_resource type="AnimationLibrary"', start)
    walk = scene[start:end].replace('length = 0.36', 'length = 0.72')
    walk = walk.replace('PackedFloat32Array(0, 0.18, 0.36)', 'PackedFloat32Array(0, 0.18, 0.36, 0.54, 0.72)')
    walk = walk.replace('PackedFloat32Array(-2, -2, -2)', 'PackedFloat32Array(-2, -2, -2, -2, -2)')
    walk = re.sub(r'"values": \[(Vector2\([^)]*\)), (Vector2\([^)]*\)), (Vector2\([^)]*\))\]', lambda m: f'"values": [{m[1]}, {m[2]}, {m[3]}, {m[2]}, {m[3]}]', walk)
    walk += track(2, 'Sprite:self_modulate', '0', ['Color(1, 1, 1, 0)'])
    walk += track(3, 'Sprite/WalkFrames:visible', '0', ['true'])
    walk += track(4, 'Sprite/WalkFrames:frame', '0, 0.18, 0.36, 0.54', ['0', '1', '2', '3'])
    scene = scene[:start] + walk + '\n' + scene[end:]
    sprite_block = scene[scene.index('[node name="Sprite"'):scene.index('[node name="WeaponMount"')]
    offset = [float(v) for v in re.search(r'offset = Vector2\(([^)]*)\)', sprite_block)[1].split(',')]
    center = [(original[i] + original[i + 2]) / 2 + offset[i] - source.size[i] / 2 for i in range(2)]
    scale = [(original[2] - original[0]) / width, (original[3] - original[1]) / height]
    node = f'''[node name="WalkFrames" type="AnimatedSprite2D" parent="Sprite"]
visible = false
position = Vector2({center[0]:.7g}, {center[1]:.7g})
scale = Vector2({scale[0]:.7g}, {scale[1]:.7g})
sprite_frames = SubResource("SpriteFrames_walk")
animation = &"walk"

'''
    scene = scene.replace('[node name="WeaponMount"', node + '[node name="WeaponMount"', 1)
    scene_path.write_text(scene)
    print(enemy, 'frame size', (width + 2, height + 2), 'center', center, 'scale', scale)
