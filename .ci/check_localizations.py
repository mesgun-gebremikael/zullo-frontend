#!/usr/bin/env python3
"""Require complete release catalogs and exact interpolation contracts."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parent.parent
arb = root / 'lib/l10n'
def read(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'{path}: duplicate {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)
source = read(arb / 'app_en.arb')
keys = {key for key in source if not key.startswith('@')}
ready = set(re.findall(r"'([^']+)'", (arb / 'locale_catalog.dart').read_text().split('static const ready =', 1)[1].split(';', 1)[0]))
for code in sorted(ready):
    data = read(arb / f'app_{code}.arb')
    actual = {key for key in data if not key.startswith('@')}
    assert actual == keys, f'{code}: missing {keys-actual}, extra {actual-keys}'
    assert data['@@locale'] == code, f'{code}: wrong locale'
    for key in keys:
        value = data[key]
        assert isinstance(value, str) and value.strip(), f'{code}: empty {key}'
        assert sorted(re.findall(r'\{(value\d+)\}', value)) == sorted(re.findall(r'\{(value\d+)\}', source[key])), f'{code}: placeholders {key}'
        assert value.count('\n') == source[key].count('\n'), f'{code}: newline {key}'
    if code != 'en':
        unchanged = sum(data[key] == source[key] for key in keys)
        assert unchanged < len(keys) * .15, f'{code}: excessive untranslated English ({unchanged})'
print(f'{len(ready)} selectable languages: {len(keys)} complete messages each; placeholder, newline, duplicate and fallback checks passed.')
