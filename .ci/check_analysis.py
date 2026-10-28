#!/usr/bin/env python3
"""Reject new analyzer findings; tolerate explicitly recorded existing debt."""
import collections
import json
from pathlib import Path
import re
import subprocess
import sys

result = subprocess.run(['flutter', 'analyze', '--no-pub'], text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout, end='')
findings = collections.Counter()
for line in result.stdout.splitlines():
    parts = re.sub(r'\x1b\[[0-9;]*m', '', line).strip().split(' • ')
    if len(parts) == 4 and parts[0] in ('info', 'warning', 'error'):
        severity, message, location, code = parts
        path = re.sub(r':\d+:\d+$', '', location)
        findings[json.dumps([severity, message, path, code], ensure_ascii=False)] += 1
baseline = collections.Counter(json.loads(
    Path(__file__).with_name('analysis_baseline.json').read_text()))
new = findings - baseline
errors = [key for key in findings if json.loads(key)[0] == 'error']
recognized = bool(re.search(r'\d+ issues? found\.|No issues found!', result.stdout))
if result.returncode not in (0, 1) or not recognized or new or errors:
    for key, count in new.items():
        print(f'NEW ({count}): {key}')
    sys.exit('Analyzer check failed: new findings, errors, or incomplete analysis.')
print(f'Analyzer baseline check passed ({sum(findings.values())} existing findings).')
