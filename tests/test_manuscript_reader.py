"""Regression tests for tracked revisions; synthetic XML, not research data."""
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile
from xml.etree import ElementTree as E
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'code'))
from check_manuscript_tables import current_view, extract_tables, visible_text, W


class RevisionReaderTests(unittest.TestCase):
    def document(self, body):
        return f'<w:document xmlns:w="{W[1:-1]}"><w:body>{body}</w:body></w:document>'

    def write_docx(self, folder, body):
        path = Path(folder)/'synthetic.docx'
        with ZipFile(path, 'w') as archive:
            archive.writestr('word/document.xml', self.document(body))
        return path

    def test_deleted_paragraph_mark_keeps_current_text(self):
        xml = self.document('<w:p><w:pPr><w:rPr><w:del w:id="1"/></w:rPr></w:pPr>'
                            '<w:r><w:t>Retained </w:t></w:r><w:del><w:r><w:delText>old</w:delText></w:r></w:del>'
                            '<w:ins><w:r><w:t>new</w:t></w:r></w:ins></w:p>')
        self.assertEqual(visible_text(current_view(E.fromstring(xml))), 'Retained new')

    def test_deleted_table_rows_do_not_shift_later_tables(self):
        body = ('<w:p><w:r><w:t>Table 8. Current</w:t></w:r></w:p>'
                '<w:tbl><w:tr><w:tc><w:p><w:del><w:r><w:delText>9</w:delText></w:r></w:del>'
                '<w:ins><w:r><w:t>8</w:t></w:r></w:ins></w:p></w:tc></w:tr></w:tbl>'
                '<w:p><w:del><w:r><w:delText>Table 8. Deleted</w:delText></w:r></w:del></w:p>'
                '<w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>obsolete</w:t>'
                '</w:r></w:p></w:tc></w:tr></w:tbl>'
                '<w:p><w:r><w:t>Supplementary Table </w:t></w:r><w:ins><w:r><w:t>S1</w:t>'
                '</w:r></w:ins></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>13 tests</w:t>'
                '</w:r></w:p></w:tc></w:tr></w:tbl>')
        with TemporaryDirectory() as temp:
            tables = extract_tables(self.write_docx(temp, body))
        self.assertEqual(tables, {'8': [['8']], 'S1': [['13 tests']]})

    def test_uncaptioned_active_table_fails(self):
        with TemporaryDirectory() as temp:
            path = self.write_docx(temp, '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>1</w:t></w:r>'
                                        '</w:p></w:tc></w:tr></w:tbl>')
            with self.assertRaisesRegex(ValueError, 'no preceding'):
                extract_tables(path)

    def test_duplicate_active_caption_fails(self):
        body = ('<w:p><w:r><w:t>Table 2. Example</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p>'
                '<w:r><w:t>1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>')
        with TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                extract_tables(self.write_docx(temp, body+body))


if __name__=='__main__':
    unittest.main()
