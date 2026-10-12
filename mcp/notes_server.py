#!/usr/bin/env python3
"""Local stdio MCP server for the Notes macOS app. No third-party packages needed."""
import contextlib
import fcntl
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import uuid

DATA_FILE = Path(os.environ.get('NOTES_DATA_FILE', Path.home() / 'Library/Application Support/Notes/notes.json')).expanduser()
LEGACY_DATA_FILE = Path.home() / 'Library/Application Support/NotesRebuild/notes.json'
LOCK_FILE = DATA_FILE.with_suffix('.lock')

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)
    def handle_starttag(self, tag, attrs):
        if tag in ('br', 'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'pre'):
            self.parts.append('\n')
    def handle_endtag(self, tag):
        if tag in ('p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'pre'):
            self.parts.append('\n')

def plain(value):
    parser = TextExtractor()
    parser.feed(value or '')
    return '\n'.join(' '.join(line.split()) for line in ''.join(parser.parts).splitlines() if line.strip())

def note_text(note):
    return note.get('markdown') or plain(note.get('html', ''))

def note_title(note):
    if note.get('title', '').strip():
        return note['title'].strip()[:90]
    markdown = note.get('markdown') or ''
    heading = re.search(r'^#\s+(.+)$', markdown, re.MULTILINE)
    if heading:
        return heading.group(1).strip()[:90]
    heading = re.search(r'<h1\b[^>]*>(.*?)</h1>', note.get('html', ''), re.IGNORECASE | re.DOTALL)
    if heading:
        return plain(heading.group(1))[:90]
    content = note_text(note)
    for line in content.splitlines():
        line = re.sub(r'^\s*#{1,6}\s+', '', line).strip()
        if line:
            return line[:90]
    return 'Untitled Note'

@contextlib.contextmanager
def transaction(write=False):
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOCK_FILE, 'a+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX if write else fcntl.LOCK_SH)
        try:
            if 'NOTES_DATA_FILE' not in os.environ and DATA_FILE == Path.home() / 'Library/Application Support/Notes/notes.json' and not DATA_FILE.exists() and LEGACY_DATA_FILE.exists():
                shutil.copy2(LEGACY_DATA_FILE, DATA_FILE)
            try:
                data = json.loads(DATA_FILE.read_text(encoding='utf-8'))
            except FileNotFoundError:
                data = {'notes': [], 'current': None}
            except json.JSONDecodeError as error:
                raise ValueError('Notes data file is not valid JSON') from error
            if not isinstance(data, dict) or not isinstance(data.get('notes'), list):
                raise ValueError('Notes data file has an invalid structure')
            yield data
            if write:
                fd, temporary = tempfile.mkstemp(prefix='.notes-', dir=DATA_FILE.parent)
                try:
                    with os.fdopen(fd, 'w', encoding='utf-8') as out:
                        json.dump(data, out, ensure_ascii=False, separators=(',', ':'))
                        out.flush()
                        os.fsync(out.fileno())
                    os.replace(temporary, DATA_FILE)
                finally:
                    if os.path.exists(temporary):
                        os.unlink(temporary)
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def summary(note):
    return {'id': note['id'], 'title': note_title(note), 'preview': note_text(note)[:180], 'pinned': bool(note.get('pinned')), 'deleted': bool(note.get('deleted')), 'updated': note.get('updated', 0)}

def find_note(data, note_id):
    note = next((item for item in data['notes'] if item.get('id') == note_id), None)
    if note is None:
        raise ValueError('Note not found')
    return note

def set_content(note, content, format_name):
    if format_name == 'markdown':
        note['markdown'] = content
        note['html'] = ''
    elif format_name == 'html':
        note['html'] = content
        note.pop('markdown', None)
    elif format_name == 'text':
        note['html'] = '<p>' + html.escape(content).replace('\n', '<br>') + '</p>'
        note.pop('markdown', None)
    else:
        raise ValueError('format must be markdown, html, or text')

def run_tool(name, args):
    if name in ('list_notes', 'search_notes'):
        query = (args.get('query') or '').casefold()
        include_deleted = bool(args.get('include_deleted', False))
        with transaction() as data:
            notes = [summary(n) for n in data['notes'] if (include_deleted or not n.get('deleted')) and query in (note_title(n) + ' ' + note_text(n)).casefold()]
        notes.sort(key=lambda n: (not n['pinned'], -n['updated']))
        return {'notes': notes}
    if name == 'get_note':
        with transaction() as data:
            note = find_note(data, args['id']).copy()
        return {'note': {**summary(note), 'content': note.get('markdown') or note.get('html', ''), 'format': 'markdown' if 'markdown' in note else 'html'}}
    if name == 'create_note':
        content = args.get('content', '')
        format_name = args.get('format', 'markdown')
        note = {'id': str(uuid.uuid4()), 'html': '', 'pinned': bool(args.get('pinned', False)), 'deleted': False, 'updated': int(time.time() * 1000)}
        if args.get('title', '').strip():
            note['title'] = args['title'].strip()[:90]
        set_content(note, content, format_name)
        with transaction(write=True) as data:
            data['notes'].insert(0, note)
            if not data.get('current'):
                data['current'] = note['id']
        return {'note': summary(note)}
    if name == 'update_note':
        with transaction(write=True) as data:
            note = find_note(data, args['id'])
            if 'content' in args:
                set_content(note, args['content'], args.get('format', 'markdown'))
            if 'pinned' in args:
                note['pinned'] = bool(args['pinned'])
            if 'title' in args:
                if args['title'].strip():
                    note['title'] = args['title'].strip()[:90]
                else:
                    note.pop('title', None)
            note['updated'] = int(time.time() * 1000)
            result = summary(note)
        return {'note': result}
    if name in ('delete_note', 'restore_note'):
        with transaction(write=True) as data:
            note = find_note(data, args['id'])
            note['deleted'] = name == 'delete_note'
            note['updated'] = int(time.time() * 1000)
            result = summary(note)
        return {'note': result}
    raise ValueError('Unknown tool')

STRING = {'type': 'string'}
TOOLS = [
    {'name':'list_notes','description':'List local Notes, optionally filtered by text. Deleted notes are excluded by default.','inputSchema':{'type':'object','properties':{'query':STRING,'include_deleted':{'type':'boolean'}}}},
    {'name':'search_notes','description':'Search local Notes by title and content.','inputSchema':{'type':'object','properties':{'query':STRING,'include_deleted':{'type':'boolean'}},'required':['query']}},
    {'name':'get_note','description':'Read a note by ID, including its content and format.','inputSchema':{'type':'object','properties':{'id':STRING},'required':['id']}},
    {'name':'create_note','description':'Create a local note from Markdown, HTML, or plain text.','inputSchema':{'type':'object','properties':{'content':STRING,'title':STRING,'format':{'type':'string','enum':['markdown','html','text']},'pinned':{'type':'boolean'}},'required':['content']}},
    {'name':'update_note','description':'Update a note body, title, or pin status by ID.','inputSchema':{'type':'object','properties':{'id':STRING,'title':STRING,'content':STRING,'format':{'type':'string','enum':['markdown','html','text']},'pinned':{'type':'boolean'}},'required':['id']}},
    {'name':'delete_note','description':'Move a note to Recently Deleted so it can be restored.','inputSchema':{'type':'object','properties':{'id':STRING},'required':['id']}},
    {'name':'restore_note','description':'Restore a note from Recently Deleted.','inputSchema':{'type':'object','properties':{'id':STRING},'required':['id']}}
]

def dispatch(request):
    method = request.get('method')
    if method == 'initialize':
        wanted = request.get('params', {}).get('protocolVersion', '2025-11-25')
        version = wanted if wanted in ('2024-11-05', '2025-03-26', '2025-06-18', '2025-11-25') else '2025-11-25'
        return {'protocolVersion': version, 'capabilities': {'tools': {'listChanged': False}}, 'serverInfo': {'name': 'notes-local', 'version': '1.0.0'}, 'instructions': 'These tools manage the local Notes macOS app. Read a note before updating it. Deletes are recoverable.'}
    if method == 'ping':
        return {}
    if method == 'tools/list':
        return {'tools': TOOLS}
    if method == 'resources/list':
        return {'resources': []}
    if method == 'prompts/list':
        return {'prompts': []}
    if method == 'tools/call':
        params = request.get('params') or {}
        try:
            result = run_tool(params.get('name'), params.get('arguments') or {})
            return {'content': [{'type':'text','text':json.dumps(result, ensure_ascii=False)}], 'structuredContent': result}
        except (ValueError, KeyError, TypeError) as error:
            return {'content': [{'type':'text','text':str(error)}], 'isError': True}
    raise KeyError(method)

def main():
    for line in sys.stdin:
        try:
            request = json.loads(line)
            if 'id' not in request:
                continue
            try:
                response = {'jsonrpc':'2.0','id':request['id'],'result':dispatch(request)}
            except KeyError:
                response = {'jsonrpc':'2.0','id':request['id'],'error':{'code':-32601,'message':'Method not found'}}
            print(json.dumps(response, ensure_ascii=False, separators=(',', ':')), flush=True)
        except Exception as error:
            print(f'Notes MCP error: {error}', file=sys.stderr, flush=True)

if __name__ == '__main__':
    main()
