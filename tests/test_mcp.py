import importlib.util
from pathlib import Path
import tempfile
import unittest


SERVER_PATH = Path(__file__).resolve().parents[1] / 'mcp' / 'notes_server.py'
spec = importlib.util.spec_from_file_location('notes_server', SERVER_PATH)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class NotesMCPTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        server.DATA_FILE = Path(self.directory.name) / 'notes.json'
        server.LOCK_FILE = server.DATA_FILE.with_suffix('.lock')

    def tearDown(self):
        self.directory.cleanup()

    def test_html_title_stops_at_first_block(self):
        self.assertEqual(server.note_title({'html': '<h1>Launch plan</h1><p>Body text</p>'}), 'Launch plan')
        self.assertEqual(server.note_title({'html': '<p>Introduction</p><h1>Launch plan</h1>'}), 'Launch plan')
        self.assertEqual(server.note_title({'title': 'Custom name', 'html': '<h1>Launch plan</h1>'}), 'Custom name')

    def test_rename_note_updates_search(self):
        created = server.run_tool('create_note', {'content': '# First name'})['note']
        renamed = server.run_tool('update_note', {'id': created['id'], 'title': 'Project plan'})['note']
        self.assertEqual(renamed['title'], 'Project plan')
        self.assertEqual(len(server.run_tool('search_notes', {'query': 'Project plan'})['notes']), 1)

    def test_create_search_update_delete_restore(self):
        created = server.run_tool('create_note', {'content': '# Launch plan\nFirst draft'})['note']
        note_id = created['id']
        self.assertEqual(created['title'], 'Launch plan')
        self.assertEqual(len(server.run_tool('search_notes', {'query': 'draft'})['notes']), 1)
        server.run_tool('update_note', {'id': note_id, 'content': '<h2>Revised</h2><p>Details</p>', 'format': 'html', 'pinned': True})
        detail = server.run_tool('get_note', {'id': note_id})['note']
        self.assertEqual((detail['title'], detail['format'], detail['pinned']), ('Revised', 'html', True))
        server.run_tool('delete_note', {'id': note_id})
        self.assertEqual(server.run_tool('list_notes', {})['notes'], [])
        server.run_tool('restore_note', {'id': note_id})
        self.assertEqual(len(server.run_tool('list_notes', {})['notes']), 1)

    def test_corrupt_file_is_never_overwritten(self):
        bad_data = '{"notes":'
        server.DATA_FILE.write_text(bad_data, encoding='utf-8')
        with self.assertRaises(ValueError):
            server.run_tool('create_note', {'content': 'Keep the corrupt file for recovery'})
        self.assertEqual(server.DATA_FILE.read_text(encoding='utf-8'), bad_data)

    def test_protocol_has_required_tools(self):
        initialized = server.dispatch({'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}})
        self.assertEqual(initialized['protocolVersion'], '2025-06-18')
        tools = server.dispatch({'method': 'tools/list'})['tools']
        self.assertEqual({tool['name'] for tool in tools}, {
            'list_notes', 'search_notes', 'get_note', 'create_note',
            'update_note', 'delete_note', 'restore_note',
        })


if __name__ == '__main__':
    unittest.main()
