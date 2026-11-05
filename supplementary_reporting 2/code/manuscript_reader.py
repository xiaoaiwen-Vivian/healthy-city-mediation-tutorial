"""Read-only comparison of a Word manuscript with calculated study results.

Tables are identified by captions, including Supplementary Tables S2 and S3.
The current revision view includes insertions and excludes deleted text/rows.
The manuscript is never changed or redistributed.
"""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
import argparse
import copy
import json
import re
import pandas as pd

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'


def current_view(root):
    """Apply revision visibility in memory, including whole-row deletions."""
    root = copy.deepcopy(root)
    for parent in list(root.iter()):
        for child in list(parent):
            if child.tag == W+'tr' and child.find('w:trPr/w:del', NS) is not None:
                parent.remove(child)
    changes = {W+x for x in ['del', 'moveFrom', 'rPrChange', 'pPrChange',
               'tblPrChange', 'trPrChange', 'tcPrChange', 'sectPrChange', 'tblGridChange']}
    for parent in list(root.iter()):
        for child in list(parent):
            if child.tag in changes:
                parent.remove(child)
    # A deleted paragraph mark merges paragraphs; surviving text is retained.
    for parent in reversed(list(root.iter())):
        for child in list(parent):
            if child.tag in {W+'ins', W+'moveTo'}:
                index = list(parent).index(child)
                parent.remove(child)
                for offset, grandchild in enumerate(list(child)):
                    parent.insert(index+offset, grandchild)
    return root


def visible_text(element):
    return ''.join(t.text or '' for t in element.iter(W+'t')).strip()


def extract_tables(docx):
    with ZipFile(docx) as archive:
        xml = current_view(E.fromstring(archive.read('word/document.xml')))
    tables = {}
    pending = None
    for element in xml.find('w:body', NS):
        if element.tag == W+'p':
            caption = re.match(r'^(?:Supplementary\s+)?Table\s+(S?\d+)\b', visible_text(element))
            if caption:
                pending = caption.group(1)
        elif element.tag == W+'tbl':
            rows = [[visible_text(cell) for cell in row.findall('w:tc', NS)]
                    for row in element.findall('w:tr', NS)]
            if not rows or not any(any(cell for cell in row) for row in rows):
                continue
            if pending is None:
                raise ValueError('An active table has no preceding numbered caption.')
            if pending in tables:
                raise ValueError(f'Duplicate active caption: Table {pending}')
            tables[pending] = rows
            pending = None
    return tables

