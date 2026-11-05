"""Reject new native probe entries without their own VBA error handler."""
import re


def validate_probe_source(source):
    entries = list(re.finditer(r'^\s*Public\s+(Function|Sub)\s+(\w+)[^\n]*\n(.*?)^\s*End\s+\1\s*$', source, re.I | re.M | re.S))
    if not entries:
        raise ValueError('Probe source needs explicit Public Function/Sub entries')
    names = set()
    for entry in entries:
        name = entry[2].lower()
        if name in names:
            raise ValueError('Duplicate probe entry: ' + name)
        names.add(name)
        handler = re.search(r'^\s*On\s+Error\s+(?:GoTo\s+([A-Za-z_]\w*)|Resume\s+Next)\b', entry[3], re.I | re.M)
        if not handler:
            raise ValueError('Native probe entry needs its own On Error handler: ' + entry[2])
        if handler[1] and not re.search(r'^\s*' + re.escape(handler[1]) + r'\s*:', entry[3], re.I | re.M):
            raise ValueError('Native probe error label is missing: ' + handler[1])
    return names
