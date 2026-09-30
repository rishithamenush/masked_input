"""Compose real app captures into a captioned MP4, poster, and README GIF.

Requires Pillow and ffmpeg. Usage: python render.py /path/to/captures
Intermediate captures stay outside the package; delivery files go to doc/media.
"""
import json
import math
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/masked-input-demo')
OUT = ROOT / 'doc' / 'media'
OUT.mkdir(parents=True, exist_ok=True)
W, H, FPS = 1600, 900, 24
FONT = Path('/System/Library/Fonts/Supplemental')

def font(size, bold=False, mono=False):
    name = Path('/System/Library/Fonts/Menlo.ttc') if mono else FONT / ('Arial Bold.ttf' if bold else 'Arial.ttf')
    return ImageFont.truetype(str(name), size)

COLORS = {'bg': '#091c22', 'panel': '#122c33', 'line': '#28464d', 'white': '#f2f8f5', 'muted': '#aec3c5', 'mint': '#86e2b9'}
SCENES = {
 'intro': ('PACKAGE DEMO', 'Inputs that\nstay in shape.', 'Phone, date, currency, and RTL.\nPredictable formatting for Flutter.', "MaskFormatter(\n  mask: '+1 (###) ###-####',\n)"),
 'phone': ('01 / PHONE MASK', 'Raw digits.\nClean display.', 'Literals appear as you type.\nRaw data stays separate.', "maskedText\n  '+1 (555) 123-4567'\nunmaskedText: '5551234567'"),
 'dynamic': ('02 / DYNAMIC MASK', 'New mask.\nSame number.', 'Add an extension at runtime.\nKeep the digits already entered.', "controller.value = mask.updateMask(\n  mask: '+1 (###) ###-#### ext. ###',\n);"),
 'edit': ('03 / POSITIONAL EDITING', 'Edit a slot.\nKeep the rest.', 'Replace a digit in the middle.\nThe caret stays near the edit.', "25/09/2026  →  26/09/2026\n\nNo reflow of later slots."),
 'delete': ('04 / LITERAL-AWARE DELETION', 'Delete digits.\nKeep structure.', 'Backspace skips punctuation.\nRefill the empty slot in place.', "26/09/2026  →  2/09/2026\n             →  25/09/2026"),
 'eager': ('05 / LITERAL COMPLETION', 'Separators,\non your terms.', 'Choose lazy or eager literals.\nChange the mode at runtime.', "MaskAutoCompletionType.lazy\n  12\nMaskAutoCompletionType.eager → 12/"),
 'currency': ('06 / CURRENCY', '125000 →\n$1,250.00', 'Group and format minor-unit digits.\nTen locale conventions included.', "CurrencyFormatter(\n  locale: 'en_US',\n  decimalDigits: 2,\n)"),
 'rtl': ('07 / RIGHT-TO-LEFT', 'Logical input.\nRTL display.', 'Flutter handles visual direction.\nRaw digit order is preserved.', "MaskFormatter(\n  mask: '###-###-####',\n  textDirection: TextDirection.rtl,\n)"),
 'outro': ('TRY THE EXAMPLE', 'One formatter.\nPer field.', 'Explore the example app.\nCopy the setup from the README.', 'cd example\nflutter pub get\nflutter run -d chrome'),
}

def wrapped(draw, text, x, y, width, f, fill, spacing=8):
    for paragraph in text.split('\n'):
        line = ''
        for word in paragraph.split(' '):
            trial = (line + ' ' + word).strip()
            if draw.textlength(trial, font=f) > width and line:
                draw.text((x,y), line, font=f, fill=fill)
                y += f.size + spacing
                line = word
            else:
                line = trial
        draw.text((x,y), line, font=f, fill=fill)
        y += f.size + spacing
    return y

background = Image.new('RGB', (W,H), COLORS['bg'])
bg = ImageDraw.Draw(background)
for y in range(H):
    blend = y / H
    bg.line((0,y,W,y),fill=(9+int(3*blend),28+int(7*blend),34+int(9*blend)))
for x in range(32,W,48):
    for y in range(24,H,48):
        bg.ellipse((x,y,x+1,y+1),fill='#20373c')


def compose(item):
    image = background.copy()
    d = ImageDraw.Draw(image)
    d.rounded_rectangle((64,54,120,110),radius=15,fill=COLORS['mint'])
    d.text((75,65),'##',font=font(28,True),fill=COLORS['bg'])
    d.text((139,59),'masked_input',font=font(42,True),fill=COLORS['white'])
    kicker, title, body, code = SCENES[item['scene']]
    d.text((64,167),kicker,font=font(19,True),fill=COLORS['mint'])
    d.multiline_text((60,211),title,font=font(65,True),fill=COLORS['white'],spacing=3)
    wrapped(d,body,64,379,670,font(26),COLORS['muted'],10)
    d.rounded_rectangle((64,489,728,637),radius=18,fill=COLORS['panel'],outline=COLORS['line'],width=1)
    # Use a slightly smaller font for long API examples; every line remains inside the panel.
    code_font = font(20,mono=True)
    d.multiline_text((86,510),code,font=code_font,fill=COLORS['mint'],spacing=7)
    wrapped(d,item['caption'],64,670,640,font(24),COLORS['white'],8)
    for x,label,width in [(64,'Flutter SDK only',190),(268,'Real app capture',205)]:
        d.rounded_rectangle((x,794,x+width,833),radius=19,outline=COLORS['line'])
        d.text((x+16,804),label,font=font(18),fill=COLORS['muted'])
    # Browser-style presentation frame, containing unaltered app screenshots.
    d.rounded_rectangle((784,40,1536,844),radius=24,fill='#1e363d',outline='#466269',width=1)
    for x,color in [(808,'#eb827b'),(828,'#e4c575'),(848,'#8cd3a7')]:
        d.ellipse((x,57,x+9,66),fill=color)
    d.text((963,54),'FLUTTER EXAMPLE',font=font(15,True),fill='#c6dad9')
    shot = Image.open(CAPTURES/item['file']).convert('RGB')
    assert shot.size == (720,740), shot.size
    image.paste(shot,(800,88))
    return image

manifest=json.loads((CAPTURES/'manifest.json').read_text())
frames=[max(1,round(item['seconds']*FPS)) for item in manifest]
total_frames=sum(frames)
command=['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-',
 '-an','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'masked-input-demo.mp4')]
process=subprocess.Popen(command,stdin=subprocess.PIPE)
previous=None
previous_scene=None
frame_index=0
chapter_starts=[]
try:
    for item,count in zip(manifest,frames):
        base=compose(item)
        changed=item['scene']!=previous_scene
        if changed:
            chapter_starts.append((frame_index/FPS,item['scene']))
            print(f"Rendering {item['scene']} at {frame_index/FPS:.2f}s",flush=True)
        for j in range(count):
            if previous is not None and changed and j<7:
                alpha=(j+1)/7
                frame=Image.blend(previous,base,alpha)
            else:
                frame=base.copy()
            draw=ImageDraw.Draw(frame)
            draw.rectangle((64,871,1536,875),fill=COLORS['line'])
            draw.rectangle((64,871,64+int(1472*(frame_index+1)/total_frames),875),fill=COLORS['mint'])
            process.stdin.write(frame.tobytes())
            frame_index+=1
        if previous is None:
            base.save(OUT/'demo-poster.png',optimize=True)
        previous=base
        previous_scene=item['scene']
finally:
    process.stdin.close()
code=process.wait()
if code: raise SystemExit(code)
(OUT/'chapters.json').write_text(json.dumps({'duration':total_frames/FPS,'chapters':[{'start':round(t,2),'scene':s} for t,s in chapter_starts]},indent=2)+'\n')
# The preview plays 3x faster, at a smaller resolution; the MP4 retains readable pacing.
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(OUT/'masked-input-demo.mp4'),
 '-filter_complex','[0:v]setpts=PTS/3,fps=8,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle',
 '-loop','0',str(OUT/'demo-preview.gif')],check=True)
print(f'Created {total_frames/FPS:.2f}s video, poster and animated preview in {OUT}',flush=True)
