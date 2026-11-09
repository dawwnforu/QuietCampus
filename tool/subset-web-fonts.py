"""Generate fixed-page WOFF2 subsets; never replace the app's full input fonts."""
from pathlib import Path
import json
from fontTools import subset
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parent.parent
portal = root / 'tool' / 'web-product'
sources = list(portal.glob('*.html')) + list(portal.glob('*.js'))
sources += [root / 'docs' / name for name in (
    'web-user-guide.zh-CN.md', 'web-user-guide.en.md', 'web-privacy-draft.md')]
text = ''.join(path.read_text(encoding='utf-8') for path in sources)
text += ''.join(chr(code) for code in range(32, 127))
text += '本地版数据说明预发布草案许可与版本使用说明返回体验首页2026年月日星期一二三四五六'
output = portal / 'fonts'
output.mkdir(exist_ok=True)
for source, family, filename in (
    ('NotoSansSC-Regular.otf', 'Quiet Portal Sans', 'quiet-portal-sans.woff2'),
    ('LXGWWenKaiLite-Regular.ttf', 'Quiet Portal Display', 'quiet-portal-display.woff2'),
):
    font = TTFont(root / 'assets' / 'fonts' / source)
    required = {ord(char) for char in text if '\u4e00' <= char <= '\u9fff'}
    assert required <= font.getBestCmap().keys(), 'Source font does not cover required Chinese UI'
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    sub = subset.Subsetter(options=options)
    sub.populate(text=text)
    sub.subset(font)
    names = {1: family, 2: 'Regular', 3: family + ' Web Subset 1',
             4: family + ' Regular', 6: family.replace(' ', '') + '-Regular',
             16: family, 17: 'Regular'}
    for record in font['name'].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    font.flavor = 'woff2'
    path = output / filename
    font.save(path)
    with TTFont(path) as checked:
        assert required <= checked.getBestCmap().keys()
    print(json.dumps({'file': filename, 'bytes': path.stat().st_size,
                      'source': source, 'chinese_glyphs': len(required)}))
