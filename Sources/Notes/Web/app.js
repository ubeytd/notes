(() => {
  const $ = (id) => document.getElementById(id);
  const editor = $('editor');
  const KEY = 'notes-local-v3';
  const SHORTCUT_KEY = 'notes-shortcuts-v2';
  const THEME_KEY = 'notes-theme-v2';
  const GLASS_KEY = 'notes-glass-v2';
  const themes = ['noir', 'graphite', 'evergreen'];
  let theme = localStorage.getItem(THEME_KEY) || 'noir';
  if (!themes.includes(theme)) theme = 'noir';
  document.documentElement.dataset.theme = theme;
  let glass = {enabled:true, strength:60};
  try { glass = {...glass,...JSON.parse(localStorage.getItem(GLASS_KEY))} } catch {}
  glass.enabled = glass.enabled !== false;
  glass.strength = Math.max(0,Math.min(100,Number(glass.strength) || 0));
  function renderGlass() {
    document.documentElement.dataset.glass = glass.enabled ? 'on' : 'off';
    document.documentElement.style.setProperty('--glass-wash',String((100-glass.strength)/180));
    document.documentElement.style.setProperty('--window-opacity',String(0.96-0.005*glass.strength*glass.strength/100));
    document.documentElement.style.setProperty('--window-blur',`${Math.round(glass.strength*0.24)}px`);
  }
  renderGlass();
  const starter = { id: crypto.randomUUID(), html: '', pinned: false, deleted: false, updated: Date.now() };
  let data;
  try { data = JSON.parse(localStorage.getItem(KEY)) } catch { data = null }
  if (!data || !Array.isArray(data.notes)) data = { notes: [starter], current: starter.id };
  if (!data.notes.some(n => n.id === data.current && !n.deleted)) data.current = data.notes.find(n => !n.deleted)?.id || null;
  let filter = 'all', search = '', actionQuery = '', saveTimer, toastTimer, findMatches = [], findIndex = 0;
  let selectedNoteIndex = 0, selectedActionIndex = 0;
  let savedRange = null, editorDirty = false;
  let diskReady = false;
  let shortcutOverrides = {}, recordingId = null, settingsQuery = '';
  try { shortcutOverrides = JSON.parse(localStorage.getItem(SHORTCUT_KEY)) || {} } catch { shortcutOverrides = {} }
  const notify = (type, payload = {}) => window.webkit?.messageHandlers?.notes?.postMessage({ type, ...payload });
  const persist = () => { const value=JSON.stringify(data); localStorage.setItem(KEY,value); if(diskReady) notify('saveData',{json:value}) };
  window.notesReceiveDiskData = raw => {
    let external; try { external=raw ? JSON.parse(raw) : null } catch { external=null }
    if (!external || !Array.isArray(external.notes)) { diskReady=true; persist(); return }
    const oldCurrentId=data.current, oldCurrentHTML=current()?.html;
    if(data.notes.length===1 && !data.notes[0].html && !data.notes[0].title && external.notes.length) data=external;
    const merged=new Map(external.notes.map(n=>[n.id,n]));
    for (const note of data.notes) if (!merged.has(note.id) || (note.updated||0) > (merged.get(note.id).updated||0)) merged.set(note.id,note);
    data.notes=Array.from(merged.values());
    for (const note of data.notes) {
      if (typeof note.markdown==='string') note.html=markdownToHTML(note.markdown);
      else note.html=DOMPurify.sanitize(note.html||'',{USE_PROFILES:{html:true}});
    }
    if (!data.notes.some(n=>n.id===data.current && !n.deleted)) data.current=data.notes.find(n=>!n.deleted)?.id||null;
    diskReady=true;
    if (!editorDirty && (data.current!==oldCurrentId || current()?.html!==oldCurrentHTML)) showCurrent();
    if (!$('browser').classList.contains('hidden')) renderList();
    if (JSON.stringify(data)!==raw) persist();
    else localStorage.setItem(KEY,JSON.stringify(data));
  };
  const current = () => data.notes.find(n => n.id === data.current);
  const plain = (html) => { const div = document.createElement('div'); div.innerHTML = html; return div.textContent || '' };
  const title = (note) => {
    if (!note) return 'Notes';
    if (note.title?.trim()) return note.title.trim().slice(0,90);
    const div = document.createElement('div'); div.innerHTML = note.html;
    if (slashOpen && note.id === data.current && /^\/[\w -]{0,40}$/.test(div.textContent.trim())) return 'Untitled Note';
    return (div.querySelector('h1')?.textContent || div.querySelector('h2,h3,p,li')?.textContent || div.textContent || 'Untitled Note').trim().split('\n')[0].slice(0, 90) || 'Untitled Note';
  };
  const preview = (note) => plain(note.html).replace(title(note), '').trim().slice(0, 120) || 'No additional text';
  function save() {
    const note = current(); if (!note) return;
    if (note.html === editor.innerHTML) { editorDirty=false; return }
    note.html = editor.innerHTML; delete note.markdown; note.updated = Date.now(); editorDirty=false; persist(); renderHeader();
  }
  function queueSave() { editorDirty=true; clearTimeout(saveTimer); saveTimer = setTimeout(save, 250) }
  function flush() { clearTimeout(saveTimer); save() }
  function renderHeader() { const note = current(); $('browseButton').firstChild.textContent = title(note) + ' '; $('pinButton').classList.toggle('is-pinned', !!note?.pinned); notify('title', { text: title(note) }) }
  function showCurrent() {
    const note = current(); editor.innerHTML = note?.html || ''; renderHeader();
    $('editorView').scrollTop = 0; persist();
  }
  function createNote() {
    flush(); const note = { id: crypto.randomUUID(), html: '', pinned: false, deleted: false, updated: Date.now() };
    data.notes.unshift(note); data.current = note.id; showCurrent(); closeOverlays();
  }
  function openNote(id) { flush(); data.current = id; showCurrent(); closeOverlays() }
  let renameTarget = null;
  function openRename(id = data.current) {
    const note=data.notes.find(item=>item.id===id); if(!note) return;
    flush();closeOverlays();renameTarget=id;
    $('renameInput').value=note.title||title(note);
    $('actionBackdrop').classList.remove('hidden');
    $('renameDialog').classList.remove('hidden');
    $('renameInput').focus();$('renameInput').select();
  }
  function saveRename() {
    const note=data.notes.find(item=>item.id===renameTarget); if(!note) {closeOverlays();return}
    const value=$('renameInput').value.trim();
    if(value)note.title=value.slice(0,90);else delete note.title;
    note.updated=Date.now();persist();renderHeader();renderList();closeOverlays();toast('Note renamed');
  }
  function togglePin() { const n = current(); if (!n) return; n.pinned = !n.pinned; n.updated = Date.now(); persist(); renderHeader(); toast(n.pinned ? 'Note pinned' : 'Note unpinned') }
  function duplicate() { flush(); const n = current(); if (!n) return; const copy = { ...n, id: crypto.randomUUID(), pinned: false, updated: Date.now() }; data.notes.unshift(copy); data.current = copy.id; showCurrent(); toast('Note duplicated') }
  function deleteNote() { flush(); const n = current(); if (!n) return; n.deleted = true; n.updated = Date.now(); data.current = data.notes.find(x => !x.deleted)?.id || null; if (!data.current) { createNote(); return } showCurrent(); toast('Moved to Recently Deleted') }
  function recover(id) { const n = data.notes.find(x => x.id === id); if (!n) return; n.deleted = false; n.updated = Date.now(); persist(); renderList(); toast('Note recovered') }
  function adjacentNote(direction) { flush(); const notes = data.notes.filter(n => !n.deleted).sort((a,b) => Number(b.pinned)-Number(a.pinned) || b.updated-a.updated); if (notes.length < 2) return; const index = notes.findIndex(n => n.id === data.current); openNote(notes[(index + direction + notes.length) % notes.length].id) }
  function dateLabel(timestamp) { const d = new Date(timestamp); return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) }
  function renderList() {
    const list = $('notesList'); list.innerHTML = '';
    const notes = data.notes.filter(n => filter === 'deleted' ? n.deleted : !n.deleted && (filter !== 'pinned' || n.pinned)).filter(n => (title(n) + ' ' + plain(n.html)).toLowerCase().includes(search.toLowerCase())).sort((a,b) => Number(b.pinned) - Number(a.pinned) || b.updated - a.updated);
    $('noteCount').textContent = `${notes.length} ${notes.length === 1 ? 'note' : 'notes'}`;
    if (!notes.length) { const empty = document.createElement('div'); empty.className = 'empty-list'; empty.textContent = filter === 'deleted' ? 'No recently deleted notes' : 'No notes found'; list.append(empty) }
    for (const note of notes) {
      const row = document.createElement('button'); row.className = 'note-row' + (note.id === data.current ? ' active' : ''); row.setAttribute('role','option'); row.setAttribute('aria-selected',String(note.id === data.current));
      const icon = document.createElement('span'); icon.className = 'note-row-icon'; const iconImage = document.createElement('img'); iconImage.src = 'icons/' + (note.deleted ? 'trash' : note.pinned ? 'pin' : 'notebook-pen') + '.svg'; iconImage.alt = ''; icon.append(iconImage);
      const body = document.createElement('span'); body.className = 'note-row-text';
      const name = document.createElement('div'); name.className = 'note-row-title'; name.textContent = title(note);
      const sub = document.createElement('div'); sub.className = 'note-row-preview'; sub.textContent = preview(note);
      const date = document.createElement('span'); date.className = 'note-row-date'; date.textContent = dateLabel(note.updated);
      body.append(name,sub); row.append(icon,body,date);
      row.addEventListener('click', () => note.deleted ? recover(note.id) : openNote(note.id));
      row.addEventListener('contextmenu', event => {event.preventDefault();openRename(note.id)});
      row.addEventListener('mouseenter', () => { selectedNoteIndex=notes.indexOf(note); syncLauncherSelection('browser') });
      row.addEventListener('focus', () => { selectedNoteIndex=notes.indexOf(note); syncLauncherSelection('browser') });
      list.append(row);
    }
    selectedNoteIndex = Math.min(selectedNoteIndex,Math.max(0,notes.length-1));
    syncLauncherSelection('browser');
  }
  function openBrowser() { flush(); closeOverlays(); $('browser').classList.remove('hidden'); $('actionBackdrop').classList.remove('hidden'); search=''; $('search').value=''; selectedNoteIndex=0; renderList(); document.activeElement?.blur() }
  function closeOverlays() {
    const active=document.activeElement;
    const inOverlay=['browser','actions','settings','findBar','formatMenu','linkMenu','slashMenu','renameDialog'].some(id=>$(id).contains(active));
    for(const id of ['browser','actions','settings','actionBackdrop','findBar','formatMenu','linkMenu','slashMenu','renameDialog']) $(id).classList.add('hidden');
    if(inOverlay) active?.blur();
    slashOpen=false;
    recordingId=null;
  }
  function toast(message) { const el = $('toast'); el.textContent = message; el.classList.remove('hidden'); clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.add('hidden'), 1800) }
  let lastStorageErrorAt = 0;
  window.notesStorageError = operation => {
    if (Date.now() - lastStorageErrorAt < 10000) return;
    lastStorageErrorAt = Date.now();
    toast(operation === 'read' ? 'Could not read notes from disk' : 'Could not save notes to disk');
  };
  const turndown = new TurndownService({headingStyle:'atx',codeBlockStyle:'fenced',bulletListMarker:'-',emDelimiter:'*'});
  turndown.use(turndownPluginGfm.gfm);
  turndown.addRule('taskItem', {
    filter: node => node.nodeName === 'LI' && !!node.querySelector('input[type="checkbox"]'),
    replacement: (content,node) => '- [' + (node.querySelector('input')?.checked ? 'x' : ' ') + '] ' + content.trim().replace(/^\[[ x]\]\s*/i,'') + '\n'
  });
  turndown.addRule('plainPreBlock', {
    filter: node => node.nodeName === 'PRE',
    replacement: (_,node) => {
      const content=node.textContent.replace(/\n+$/,'');
      const ticks=Math.max(3,...Array.from(content.matchAll(/`+/g),match=>match[0].length+1));
      const fence='`'.repeat(ticks);
      return `\n\n${fence}\n${content}\n${fence}\n\n`;
    }
  });
  function markdown(html) { return turndown.turndown(html).trim() }
  const actions = [
    {id:'new',label:'New Note',group:'Notes',shortcut:'Meta+N',icon:'plus',run:createNote},
    {id:'rename',label:'Rename Note',group:'Notes',shortcut:'Meta+Shift+R',icon:'notebook-pen',run:()=>openRename()},
    {id:'browse',label:'Browse Notes',group:'Notes',shortcut:'Meta+O',icon:'notebook-pen',run:openBrowser},
    {id:'globalNew',label:'Create New Note From Anywhere',group:'Global Shortcuts',shortcut:'Ctrl+Alt+N',icon:'plus',run:createNote},
    {id:'globalBrowse',label:'Browse Notes From Anywhere',group:'Global Shortcuts',shortcut:'Ctrl+Alt+O',icon:'notebook-pen',run:openBrowser},
    {id:'next',label:'Next Note',group:'Notes',shortcut:'Meta+Alt+ArrowDown',icon:'chevron-down',run:()=>adjacentNote(1)},
    {id:'previous',label:'Previous Note',group:'Notes',shortcut:'Meta+Alt+ArrowUp',icon:'chevron-down',run:()=>adjacentNote(-1)},
    {id:'duplicate',label:'Duplicate Note',group:'Notes',shortcut:'Meta+Shift+D',icon:'copy',run:duplicate},
    {id:'pin',label:'Pin or Unpin Note',group:'Notes',shortcut:'Meta+Shift+P',icon:'pin',run:togglePin},
    {id:'delete',label:'Move Note to Recently Deleted',group:'Notes',shortcut:'',icon:'trash',run:deleteNote},
    {id:'actions',label:'Show Actions',group:'Navigation',shortcut:'Meta+K',icon:'command',run:openActions},
    {id:'settings',label:'Settings',group:'Navigation',shortcut:'Meta+,',icon:'settings',run:openSettings},
    {id:'shortcutSettings',label:'Keyboard Shortcut Settings',group:'Navigation',shortcut:'',icon:'keyboard',run:()=>openSettings('shortcuts')},
    {id:'mcpSettings',label:'MCP Server Settings',group:'Navigation',shortcut:'',icon:'settings',run:()=>openSettings('mcp')},
    {id:'find',label:'Find in Note',group:'Navigation',shortcut:'Meta+F',icon:'search',run:openFind},
    {id:'toggleToolbar',label:'Show or Hide Formatting Bar',group:'Navigation',shortcut:'Meta+Alt+T',icon:'settings',run:()=>notify('toggleToolbar')},
    {id:'save',label:'Save Note',group:'Navigation',shortcut:'Meta+S',icon:'check',run:()=>{flush();toast('Saved')}},
    {id:'bold',label:'Bold',group:'Text Style',shortcut:'Meta+B',icon:'bold',editorOnly:true,run:()=>command('bold')},
    {id:'italic',label:'Italic',group:'Text Style',shortcut:'Meta+I',icon:'italic',editorOnly:true,run:()=>command('italic')},
    {id:'underline',label:'Underline',group:'Text Style',shortcut:'Meta+U',icon:'underline',editorOnly:true,run:()=>command('underline')},
    {id:'strike',label:'Strikethrough',group:'Text Style',shortcut:'Meta+Shift+X',icon:'minus',editorOnly:true,run:()=>command('strike')},
    {id:'inlineCode',label:'Inline Code',group:'Text Style',shortcut:'Meta+E',icon:'code',editorOnly:true,run:()=>command('inlineCode')},
    {id:'link',label:'Add Link',group:'Text Style',shortcut:'Meta+Shift+K',icon:'link',editorOnly:true,run:()=>command('link')},
    {id:'unlink',label:'Remove Link',group:'Text Style',shortcut:'',icon:'link-2-off',editorOnly:true,run:()=>command('unlink')},
    {id:'clear',label:'Clear Formatting',group:'Text Style',shortcut:'',icon:'remove-formatting',editorOnly:true,run:()=>command('clear')},
    {id:'h1',label:'Heading 1',group:'Blocks and Lists',shortcut:'Meta+Alt+1',icon:'heading-1',editorOnly:true,run:()=>command('h1')},
    {id:'h2',label:'Heading 2',group:'Blocks and Lists',shortcut:'Meta+Alt+2',icon:'heading-2',editorOnly:true,run:()=>command('h2')},
    {id:'h3',label:'Heading 3',group:'Blocks and Lists',shortcut:'Meta+Alt+3',icon:'heading-3',editorOnly:true,run:()=>command('h3')},
    {id:'paragraph',label:'Paragraph',group:'Blocks and Lists',shortcut:'Meta+Alt+0',icon:'list',editorOnly:true,run:()=>command('paragraph')},
    {id:'bullet',label:'Bulleted List',group:'Blocks and Lists',shortcut:'Meta+Shift+8',icon:'list',editorOnly:true,run:()=>command('bullet')},
    {id:'ordered',label:'Numbered List',group:'Blocks and Lists',shortcut:'Meta+Shift+7',icon:'list-ordered',editorOnly:true,run:()=>command('ordered')},
    {id:'checklist',label:'Checklist',group:'Blocks and Lists',shortcut:'Meta+Shift+9',icon:'list-checks',editorOnly:true,run:()=>command('checklist')},
    {id:'quote',label:'Quote Block',group:'Blocks and Lists',shortcut:'Meta+Shift+Q',icon:'quote',editorOnly:true,run:()=>command('quote')},
    {id:'code',label:'Code Block',group:'Blocks and Lists',shortcut:'Meta+Alt+C',icon:'code-xml',editorOnly:true,run:()=>command('code')},
    {id:'rule',label:'Horizontal Rule',group:'Blocks and Lists',shortcut:'Meta+Alt+H',icon:'separator-horizontal',editorOnly:true,run:()=>command('rule')},
    {id:'indent',label:'Indent List',group:'Blocks and Lists',shortcut:'Meta+]',icon:'indent-increase',editorOnly:true,run:()=>command('indent')},
    {id:'outdent',label:'Outdent List',group:'Blocks and Lists',shortcut:'Meta+[',icon:'indent-decrease',editorOnly:true,run:()=>command('outdent')},
    {id:'date',label:'Insert Current Date',group:'Insert and Export',shortcut:'Meta+Alt+D',icon:'plus',editorOnly:true,run:()=>command('date')},
    {id:'renderMarkdown',label:'Render Existing Markdown',group:'Insert and Export',shortcut:'',icon:'code',run:renderExistingMarkdown},
    {id:'copyMarkdown',label:'Copy Note as Markdown',group:'Insert and Export',shortcut:'Meta+Shift+C',icon:'copy',run:()=>copy('md')},
    {id:'copyText',label:'Copy Note as Plain Text',group:'Insert and Export',shortcut:'',icon:'copy',run:()=>copy('txt')},
    {id:'copyHTML',label:'Copy Note as HTML',group:'Insert and Export',shortcut:'',icon:'copy',run:()=>copy('html')},
    {id:'exportMarkdown',label:'Export as Markdown',group:'Insert and Export',shortcut:'',icon:'file-output',run:()=>exportNote('md')},
    {id:'exportText',label:'Export as Plain Text',group:'Insert and Export',shortcut:'',icon:'file-output',run:()=>exportNote('txt')},
    {id:'exportHTML',label:'Export as HTML',group:'Insert and Export',shortcut:'',icon:'file-output',run:()=>exportNote('html')}
  ];
  const shortcutFor = action => Object.prototype.hasOwnProperty.call(shortcutOverrides,action.id) ? shortcutOverrides[action.id] : action.shortcut;
  function shortcutLabel(value) { return value ? value.split('+').map(part => ({Meta:'⌘',Ctrl:'⌃',Alt:'⌥',Shift:'⇧',ArrowUp:'↑',ArrowDown:'↓',ArrowLeft:'←',ArrowRight:'→',Backspace:'⌫',Delete:'⌦',Space:'Space'}[part] || part)).join('') : 'Set Shortcut' }
  function eventShortcut(event) {
    const code = event.code || '', raw = event.key;
    if (['Meta','Control','Alt','Shift'].includes(raw)) return null;
    const key = /^Key[A-Z]$/.test(code) ? code.slice(3) : /^Digit[0-9]$/.test(code) ? code.slice(5) : raw.length === 1 ? raw.toUpperCase() : raw;
    return [...(event.metaKey?['Meta']:[]),...(event.ctrlKey?['Ctrl']:[]),...(event.altKey?['Alt']:[]),...(event.shiftKey?['Shift']:[]),key].join('+');
  }
  function renderExistingMarkdown() {
    const source = editor.innerText;
    if (!source.trim()) return;
    editor.innerHTML = markdownToHTML(source);
    flush(); closeOverlays(); toast('Markdown rendered');
  }
  function copy(format) { flush(); const n = current(); if (!n) return; notify('clipboard',{text: format === 'html' ? n.html : format === 'md' ? markdown(n.html) : plain(n.html)}); closeOverlays(); toast('Copied to clipboard') }
  function exportNote(format) { flush(); const n = current(); if (!n) return; notify('export',{name:title(n).replace(/[/:]/g,'-')+'.'+format,text:format === 'html' ? '<!doctype html><meta charset="utf-8">'+n.html : format === 'md' ? markdown(n.html) : plain(n.html)}); closeOverlays() }
  function launcherRows(kind) { return [...$(kind==='browser'?'notesList':'actionItems').querySelectorAll(kind==='browser'?'.note-row':'.action-item')] }
  function syncLauncherSelection(kind, scroll=false) {
    const rows=launcherRows(kind), index=kind==='browser'?selectedNoteIndex:selectedActionIndex;
    rows.forEach((row,i)=>row.classList.toggle('selected',i===index));
    if(scroll) rows[index]?.scrollIntoView({block:'nearest'});
  }
  function moveLauncherSelection(kind, direction) {
    const rows=launcherRows(kind); if(!rows.length) return;
    if(kind==='browser') selectedNoteIndex=(selectedNoteIndex+direction+rows.length)%rows.length;
    else selectedActionIndex=(selectedActionIndex+direction+rows.length)%rows.length;
    syncLauncherSelection(kind,true);
  }
  function selectLauncherRow(kind) { const rows=launcherRows(kind); rows[kind==='browser'?selectedNoteIndex:selectedActionIndex]?.click() }
  function renderActions() {
    const list=$('actionItems'); list.innerHTML=''; let lastGroup='';
    for(const action of actions.filter(a => (a.label+' '+a.group).toLowerCase().includes(actionQuery.toLowerCase()))) {
      if (action.group !== lastGroup) { const heading=document.createElement('div'); heading.className='action-group'; heading.textContent=action.group; list.append(heading); lastGroup=action.group }
      const row=document.createElement('button'); row.className='action-item';
      row.innerHTML=`<span class="action-label"><img src="icons/${action.icon}.svg" alt=""><span></span></span><small></small>`;
      row.querySelector('.action-label span').textContent=action.label;
      row.querySelector('small').textContent=shortcutFor(action)?shortcutLabel(shortcutFor(action)):'';
      row.onclick=()=>{closeOverlays();action.run()};
      row.addEventListener('mouseenter',()=>{selectedActionIndex=launcherRows('actions').indexOf(row);syncLauncherSelection('actions')});
      row.addEventListener('focus',()=>{selectedActionIndex=launcherRows('actions').indexOf(row);syncLauncherSelection('actions')});
      list.append(row);
    }
    selectedActionIndex=Math.min(selectedActionIndex,Math.max(0,launcherRows('actions').length-1));
    syncLauncherSelection('actions');
  }
  function openActions() { closeOverlays(); $('actions').classList.remove('hidden'); $('actionBackdrop').classList.remove('hidden'); actionQuery=''; $('actionSearch').value=''; selectedActionIndex=0; renderActions(); document.activeElement?.blur() }
  function settingsMessage(message, error = false) { $('settingsMessage').textContent = message; $('settingsMessage').classList.toggle('error', error) }
  function renderSettings() {
    const list = $('settingsList'); list.innerHTML = ''; let group = '';
    for (const action of actions.filter(a => (a.label+' '+a.group).toLowerCase().includes(settingsQuery.toLowerCase()))) {
      if (action.group !== group) { const heading=document.createElement('div'); heading.className='settings-group'; heading.textContent=action.group; list.append(heading); group=action.group }
      const row=document.createElement('div'); row.className='settings-row';
      const title=document.createElement('span'); title.textContent=action.label;
      const key=document.createElement('button'); key.className='shortcut-recorder' + (recordingId===action.id?' recording':''); key.textContent=recordingId===action.id?'Press keys…':shortcutLabel(shortcutFor(action)); key.setAttribute('aria-label',`Change shortcut for ${action.label}`);
      key.onclick=()=>{ recordingId=action.id; renderSettings(); list.querySelector('.shortcut-recorder.recording')?.focus(); settingsMessage(`Press a shortcut for ${action.label}. Backspace clears it; Esc cancels.`) };
      row.append(title,key); list.append(row);
    }
    if (!list.children.length) { const empty=document.createElement('div'); empty.className='settings-empty'; empty.textContent='No matching shortcuts'; list.append(empty) }
  }
  function selectSettingsTab(tab) {
    const mcp=tab==='mcp';
    $('shortcutSettings').classList.toggle('hidden',mcp); $('mcpSettings').classList.toggle('hidden',!mcp);
    $('shortcutTab').classList.toggle('active',!mcp); $('mcpTab').classList.toggle('active',mcp);
    $('shortcutTab').setAttribute('aria-selected',String(!mcp)); $('mcpTab').setAttribute('aria-selected',String(mcp));
    if (mcp) notify('mcpInfo');
  }
  function openSettings(tab='appearance') {
    flush(); closeOverlays(); document.activeElement?.blur();
    const snapshot=actions.map(action=>({id:action.id,label:action.label,group:action.group,shortcut:shortcutFor(action),defaultShortcut:action.shortcut}));
    notify('openSettings',{tab,actions:JSON.stringify(snapshot),theme,glassEnabled:String(glass.enabled),glassStrength:String(glass.strength)});
  }
  window.notesOpenSettings = openSettings;
  window.notesSetTheme = value => {
    if (!themes.includes(value)) return;
    theme = value;
    localStorage.setItem(THEME_KEY, theme);
    document.documentElement.dataset.theme = theme;
    notify('themeChanged', {theme});
  };
  window.notesSetGlass = (enabled,strength) => {
    glass.enabled = !!enabled;
    glass.strength = Math.max(0,Math.min(100,Number(strength) || 0));
    localStorage.setItem(GLASS_KEY,JSON.stringify(glass));
    renderGlass();
    notify('glassChanged',{enabled:String(glass.enabled),strength:String(glass.strength)});
  };
  let mcpServerPath='', mcpDataPath='';
  window.notesMcpInfo = info => { mcpServerPath=info.server; mcpDataPath=info.data; $('mcpDataPath').textContent=mcpDataPath; renderMcpConfig() };
  function renderMcpConfig() {
    const server=mcpServerPath||'/path/to/Notes.app/Contents/Resources/notes_mcp_server.py';
    const command='/usr/bin/python3', choice=$('mcpAgent').value;
    const entry={command,args:[server]};
    let name,config;
    if(choice==='codex') {name='~/.codex/config.toml';config='[mcp_servers.notes]\ncommand = '+JSON.stringify(command)+'\nargs = ['+JSON.stringify(server)+']'}
    else if(choice==='vscode') {name='.vscode/mcp.json';config=JSON.stringify({servers:{notes:{type:'stdio',...entry}}},null,2)}
    else {name=choice==='claude'?'~/Library/Application Support/Claude/claude_desktop_config.json':choice==='claudeCode'?'.mcp.json (project root)':choice==='cursor'?'~/.cursor/mcp.json':'Your agent’s MCP config';config=JSON.stringify({mcpServers:{notes:entry}},null,2)}
    $('mcpConfigName').textContent=name; $('mcpConfig').textContent=config;
  }
  function syncGlobalShortcuts() { notify('globalShortcuts',{shortcuts:JSON.stringify(Object.fromEntries(actions.filter(a=>a.group==='Global Shortcuts').map(a=>[a.id,shortcutFor(a)])))}) }
  window.notesRunGlobalAction = id => { const action=actions.find(a=>a.id===id && a.group==='Global Shortcuts'); action?.run() };
  function saveShortcut(id, value) { shortcutOverrides[id]=value; localStorage.setItem(SHORTCUT_KEY,JSON.stringify(shortcutOverrides)); recordingId=null; renderSettings(); renderActions(); updateShortcutHints(); syncGlobalShortcuts(); settingsMessage(value?'Shortcut updated.':'Shortcut cleared.') }
  window.notesSetShortcut = saveShortcut;
  window.notesResetShortcuts = () => { shortcutOverrides={}; localStorage.setItem(SHORTCUT_KEY,'{}'); recordingId=null; renderSettings(); renderActions(); updateShortcutHints(); syncGlobalShortcuts() };
  function updateShortcutHints() { const get=id=>shortcutLabel(shortcutFor(actions.find(a=>a.id===id))); $('newButton').title=`New Note (${get('new')})`; $('moreButton').title=`Actions (${get('actions')})`; $('settingsButton').title=`Settings (${get('settings')})`; $('browser').querySelector('kbd').textContent=get('browse'); $('actions').querySelector('kbd').textContent=get('actions') }
  function recordShortcut(event) {
    event.preventDefault(); event.stopPropagation();
    if (event.key==='Escape') { recordingId=null; renderSettings(); settingsMessage('Recording cancelled.'); return }
    if (event.key==='Backspace' || event.key==='Delete') { saveShortcut(recordingId,''); return }
    const combo=eventShortcut(event); if (!combo) return;
    if (!(event.metaKey || event.ctrlKey || event.altKey)) { settingsMessage('Use ⌘, ⌃, or ⌥ with another key.',true); return }
    if (['Meta+C','Meta+V','Meta+X','Meta+A','Meta+Z','Meta+Shift+Z','Meta+Q','Meta+W','Meta+H','Meta+M','Meta+Tab'].includes(combo)) { settingsMessage('That shortcut is reserved by macOS editing or window controls.',true); return }
    const conflict=actions.find(a=>a.id!==recordingId && shortcutFor(a)===combo);
    if (conflict) { settingsMessage(`${shortcutLabel(combo)} is already used by ${conflict.label}.`,true); return }
    saveShortcut(recordingId,combo);
  }
  function openFind() { closeOverlays(); $('findBar').classList.remove('hidden'); document.activeElement?.blur(); updateFind() }
  function updateFind() { const q = $('findInput').value.toLowerCase(); const text = editor.textContent.toLowerCase(); findMatches = []; if(q) { let start = 0, i; while((i = text.indexOf(q,start)) !== -1) { findMatches.push(i); start = i + q.length } } findIndex = 0; $('findCount').textContent = `${findMatches.length} ${findMatches.length === 1 ? 'result' : 'results'}` }
  function moveFind(direction) { if(!findMatches.length) return; findIndex = (findIndex + direction + findMatches.length) % findMatches.length; $('findCount').textContent = `${findIndex + 1} of ${findMatches.length}`; const q = $('findInput').value; const walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT); let offset = findMatches[findIndex], node; while((node = walker.nextNode())) { if(offset < node.textContent.length) { const range = document.createRange(); range.setStart(node,offset); range.setEnd(node,Math.min(node.length,offset+q.length)); const sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(range); node.parentElement.scrollIntoView({block:'center'}); break } offset -= node.textContent.length } }
  function command(name) {
    $('formatMenu').classList.add('hidden');
    $('slashMenu').classList.add('hidden');
    slashOpen=false;
    if (savedRange) { const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(savedRange) }
    editor.focus();
    if(name === 'heading' || name === 'h1') document.execCommand('formatBlock',false,'h1');
    if(name === 'h2') document.execCommand('formatBlock',false,'h2');
    if(name === 'h3') document.execCommand('formatBlock',false,'h3');
    if(name === 'paragraph') document.execCommand('formatBlock',false,'p');
    if(name === 'bold') document.execCommand('bold');
    if(name === 'italic') document.execCommand('italic');
    if(name === 'underline') document.execCommand('underline');
    if(name === 'strike') document.execCommand('strikeThrough');
    if(name === 'inlineCode') {
      const selected=window.getSelection()?.toString() || '';
      const marker='code-'+crypto.randomUUID();
      document.execCommand('insertHTML',false,`<code data-edit-marker="${marker}">${escapeHTML(selected||'code')}</code>`);
      const node=Array.from(editor.querySelectorAll('code[data-edit-marker]')).find(item=>item.dataset.editMarker===marker);
      if(node){node.removeAttribute('data-edit-marker');const range=document.createRange();if(selected)range.setStartAfter(node);else range.selectNodeContents(node);if(selected)range.collapse(true);const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range)}
    }
    if(name === 'unlink') document.execCommand('unlink');
    if(name === 'clear') document.execCommand('removeFormat');
    if(name === 'bullet') document.execCommand('insertUnorderedList');
    if(name === 'ordered') document.execCommand('insertOrderedList');
    if(name === 'checklist') document.execCommand('insertHTML',false,'<ul class="checklist"><li><input type="checkbox" contenteditable="false"> Task</li></ul>');
    if(name === 'quote') document.execCommand('formatBlock',false,'blockquote');
    if(name === 'code') document.execCommand('formatBlock',false,'pre');
    if(name === 'rule') document.execCommand('insertHorizontalRule');
    if(name === 'indent') document.execCommand('indent');
    if(name === 'outdent') document.execCommand('outdent');
    if(name === 'date') document.execCommand('insertText',false,new Date().toLocaleDateString());
    if(name === 'link') { $('linkMenu').classList.remove('hidden'); document.activeElement?.blur(); return }
    queueSave();
  }
  window.notesFormat = command;
  window.notesCloseFormatMenu = () => $('formatMenu').classList.add('hidden');
  window.notesToggleFormatMenu = name => {
    const menu = $('formatMenu');
    if (!menu.classList.contains('hidden') && menu.dataset.kind === name) { menu.classList.add('hidden'); return }
    const options = name === 'heading' ? [['Heading 1','h1'],['Heading 2','h2'],['Heading 3','h3']] : name === 'paragraph' ? [['Paragraph','paragraph'],['Bold','bold'],['Italic','italic'],['Underline','underline'],['Strikethrough','strike'],['Inline Code','inlineCode'],['Clear Formatting','clear']] : [['Bulleted List','bullet'],['Numbered List','ordered'],['Checklist','checklist']];
    menu.innerHTML = '';
    for (const [label, value] of options) { const item = document.createElement('button'); item.textContent = label; item.onclick = () => command(value); menu.append(item) }
    menu.dataset.kind = name; menu.className = 'format-menu ' + name;
  };
  const slashOptions = [
    {label:'Heading 1',detail:'Large heading',icon:'heading-1',command:'h1',keywords:'title'},
    {label:'Heading 2',detail:'Section heading',icon:'heading-2',command:'h2',keywords:'subtitle'},
    {label:'Heading 3',detail:'Small heading',icon:'heading-3',command:'h3',keywords:'subheading'},
    {label:'Paragraph',detail:'Normal text',icon:'heading',command:'paragraph',keywords:'text'},
    {label:'Bulleted List',detail:'List with bullets',icon:'list',command:'bullet',keywords:'unordered'},
    {label:'Numbered List',detail:'List with numbers',icon:'list-ordered',command:'ordered',keywords:'ordered'},
    {label:'Checklist',detail:'Track tasks',icon:'list-checks',command:'checklist',keywords:'todo task'},
    {label:'Quote',detail:'Quoted text',icon:'quote',command:'quote',keywords:'blockquote'},
    {label:'Code Block',detail:'Monospaced block',icon:'code-xml',command:'code',keywords:'pre snippet'},
    {label:'Divider',detail:'Horizontal line',icon:'separator-horizontal',command:'rule',keywords:'rule separator'},
    {label:'Bold',detail:'Strong emphasis',icon:'bold',command:'bold',keywords:'strong'},
    {label:'Italic',detail:'Emphasis',icon:'italic',command:'italic',keywords:'emphasis'},
    {label:'Inline Code',detail:'Code in a line',icon:'code',command:'inlineCode',keywords:'monospace'},
    {label:'Link',detail:'Add a URL',icon:'link',command:'link',keywords:'url'},
    {label:'Date',detail:'Insert today',icon:'plus',command:'date',keywords:'today'}
  ];
  let slashOpen = false, slashSelected = 0, slashMatches = [];
  function currentBlock() {
    const selection = window.getSelection();
    const node = selection?.anchorNode;
    const element = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
    return element?.closest('p,div,h1,h2,h3,h4,h5,h6,blockquote,pre,li') || editor;
  }
  function slashPrefix() {
    const selection = window.getSelection();
    if (!selection?.rangeCount || !selection.isCollapsed || !editor.contains(selection.anchorNode)) return null;
    const block = currentBlock();
    if (!editor.contains(block) && block !== editor) return null;
    const range = document.createRange();
    range.selectNodeContents(block);
    try { range.setEnd(selection.anchorNode,selection.anchorOffset) } catch { return null }
    return {block,range,text:range.toString()};
  }
  function closeSlashMenu() { slashOpen=false; $('slashMenu').classList.add('hidden') }
  function renderSlashMenu() {
    if (!slashOpen) return;
    const prefix = slashPrefix();
    if (!prefix || !/^\/[\w -]{0,40}$/.test(prefix.text)) { closeSlashMenu(); return }
    const query = prefix.text.slice(1).trim().toLowerCase();
    slashMatches = slashOptions.filter(item=>(item.label+' '+item.keywords).toLowerCase().includes(query));
    slashSelected = Math.min(slashSelected,Math.max(0,slashMatches.length-1));
    const menu=$('slashMenu'); menu.innerHTML='';
    if (!slashMatches.length) { const empty=document.createElement('div'); empty.className='slash-empty'; empty.textContent='No matching options'; menu.append(empty) }
    for (const [index,item] of slashMatches.entries()) {
      const row=document.createElement('button'); row.type='button'; row.className='slash-item'+(index===slashSelected?' selected':''); row.setAttribute('role','option'); row.setAttribute('aria-selected',String(index===slashSelected));
      const icon=document.createElement('img'); icon.src='icons/'+item.icon+'.svg'; icon.alt='';
      const text=document.createElement('span'); text.className='slash-item-text';
      const name=document.createElement('strong'); name.textContent=item.label;
      const detail=document.createElement('small'); detail.textContent=item.detail;
      text.append(name,detail); row.append(icon,text);
      row.onmousedown=e=>e.preventDefault(); row.onclick=()=>selectSlash(index);
      menu.append(row);
    }
    menu.classList.remove('hidden');
    const caret=window.getSelection()?.getRangeAt(0)?.getBoundingClientRect();
    const app=$('app').getBoundingClientRect();
    const x=Math.min(Math.max((caret?.left||app.left)-app.left,12),app.width-292);
    const below=(caret?.bottom||app.top+70)-app.top+7;
    menu.style.left=`${x}px`;
    menu.style.top=`${below+Math.min(menu.scrollHeight,310)>app.height-14?Math.max(12,(caret?.top||app.top)-app.top-Math.min(menu.scrollHeight,310)-7):below}px`;
  }
  function selectSlash(index) {
    const item=slashMatches[index]; if (!item) return;
    const prefix=slashPrefix(); if (!prefix) { closeSlashMenu(); return }
    closeSlashMenu();
    const selection=window.getSelection(); selection.removeAllRanges(); selection.addRange(prefix.range);
    document.execCommand('delete');
    if (selection.rangeCount) savedRange=selection.getRangeAt(0).cloneRange();
    command(item.command);
    queueSave();
  }
  document.addEventListener('selectionchange', () => {
    const selection = window.getSelection();
    if (selection.rangeCount && editor.contains(selection.anchorNode)) savedRange = selection.getRangeAt(0).cloneRange();
  });
  const escapeHTML = text => text.replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  function markdownToHTML(source) {
    const template = document.createElement('template');
    template.innerHTML = DOMPurify.sanitize(marked.parse(source,{gfm:true,breaks:false}),{USE_PROFILES:{html:true}});
    template.content.querySelectorAll('input[type="checkbox"]').forEach(input => {
      input.removeAttribute('disabled'); input.setAttribute('contenteditable','false');
      const list = input.closest('ul'); if (list) list.classList.add('checklist');
    });
    return template.innerHTML;
  }
  function cleanPastedHTML(source) {
    const template = document.createElement('template');
    template.innerHTML = DOMPurify.sanitize(source,{USE_PROFILES:{html:true}});
    template.content.querySelectorAll('[style]').forEach(element => element.removeAttribute('style'));
    return template.innerHTML;
  }
  editor.addEventListener('paste', event => {
    const text = event.clipboardData?.getData('text/plain');
    const html = event.clipboardData?.getData('text/html');
    if (!text && !html) return;
    event.preventDefault();
    const markdownLike = /(^|\n)\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>\s|```|~~~|\|[^\n]+\||-{3,}\s*$)|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\)|`[^`]+`|~~[^~]+~~/.test(text);
    if (markdownLike) document.execCommand('insertHTML', false, markdownToHTML(text));
    else if (html) document.execCommand('insertHTML', false, cleanPastedHTML(html));
    else document.execCommand('insertText', false, text);
    queueSave();
  });
  $('browseButton').onclick=openBrowser; $('newButton').onclick=createNote; $('browserNew').onclick=createNote; $('pinButton').onclick=togglePin; $('settingsButton').onclick=()=>openSettings(); $('moreButton').onclick=openActions;
  $('actionBackdrop').onclick=closeOverlays;
  $('renameCancel').onclick=closeOverlays;
  $('renameSave').onclick=saveRename;
  $('renameInput').onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();saveRename()}else if(e.key==='Escape'){e.preventDefault();closeOverlays()}};
  $('settingsClose').onclick=closeOverlays;
  $('shortcutTab').onclick=()=>selectSettingsTab('shortcuts'); $('mcpTab').onclick=()=>selectSettingsTab('mcp');
  $('mcpAgent').onchange=renderMcpConfig;
  $('copyMcpConfig').onclick=()=>{notify('clipboard',{text:$('mcpConfig').textContent});toast('Configuration copied')};
  $('settingsSearch').oninput=e=>{settingsQuery=e.target.value;renderSettings()};
  $('resetShortcuts').onclick=()=>{window.notesResetShortcuts();settingsMessage('Default shortcuts restored.');toast('Shortcuts reset')};
  $('linkCancel').onclick=()=>{ $('linkMenu').classList.add('hidden'); document.activeElement?.blur() };
  $('linkApply').onclick=()=>{ const value=$('linkInput').value.trim(); $('linkMenu').classList.add('hidden'); if (!value) { document.activeElement?.blur(); return } if (savedRange) { const selection=window.getSelection(); selection.removeAllRanges(); selection.addRange(savedRange) } editor.focus(); document.execCommand('createLink',false,value); queueSave(); editor.blur() };
  $('linkInput').onkeydown=e=>{ if(e.key==='Enter'){e.preventDefault();$('linkApply').click()} };
  $('search').oninput=e=>{search=e.target.value;selectedNoteIndex=0;renderList()}; $('actionSearch').oninput=e=>{actionQuery=e.target.value;selectedActionIndex=0;renderActions()};
  function setNoteFilter(value) { filter=value; selectedNoteIndex=0; document.querySelectorAll('.browser-tabs button').forEach(button=>{const active=button.dataset.filter===value;button.classList.toggle('active',active);button.setAttribute('aria-selected',String(active))});renderList() }
  document.querySelectorAll('.browser-tabs button').forEach(b=>b.onclick=()=>setNoteFilter(b.dataset.filter));
  document.querySelectorAll('.format').forEach(b=>b.onclick=()=>command(b.dataset.command));
  $('findInput').oninput=updateFind; $('findNext').onclick=()=>moveFind(1); $('findPrev').onclick=()=>moveFind(-1); $('findClose').onclick=()=>{ $('findBar').classList.add('hidden');document.activeElement?.blur() };
  editor.oninput=()=>{queueSave();if(slashOpen){slashSelected=0;renderSlashMenu()}};
  editor.addEventListener('click',e=>{if(slashOpen)closeSlashMenu();if(e.target.matches('input[type="checkbox"]')){e.target.toggleAttribute('checked',e.target.checked);queueSave()}}); $('editorView').onclick=e=>{if(e.target===e.currentTarget)editor.focus()};
  editor.addEventListener('keydown',e=>{
    const selection=window.getSelection();
    const anchor=selection?.anchorNode;
    const element=anchor?.nodeType===Node.ELEMENT_NODE?anchor:anchor?.parentElement;
    if(e.key===' '&&!e.metaKey&&!e.ctrlKey&&!e.altKey&&!e.isComposing){
      const prefix=slashPrefix();
      const level=prefix?.text.match(/^(#{1,6})$/)?.[1].length;
      if(level&&(prefix.block===editor||prefix.block.matches('p,div,h1,h2,h3,h4,h5,h6'))){
        e.preventDefault();e.stopPropagation();
        prefix.range.deleteContents();prefix.range.collapse(true);
        selection.removeAllRanges();selection.addRange(prefix.range);
        document.execCommand('formatBlock',false,`h${level}`);
        queueSave();return;
      }
    }
    const heading=element?.closest('h1,h2,h3,h4,h5,h6');
    if(heading&&editor.contains(heading)&&e.key==='Enter'&&!e.shiftKey&&!e.isComposing){
      const range=selection?.rangeCount?selection.getRangeAt(0):null;
      if(range&&heading.contains(range.startContainer)&&heading.contains(range.endContainer)){
        e.preventDefault();e.stopPropagation();
        if(!selection.isCollapsed)range.deleteContents();
        const tail=document.createRange();tail.selectNodeContents(heading);
        tail.setStart(range.startContainer,range.startOffset);
        const paragraph=document.createElement('p');paragraph.append(tail.extractContents());
        if(!paragraph.textContent.trim())paragraph.replaceChildren(document.createElement('br'));
        heading.after(paragraph);
        if(!heading.textContent.trim())heading.remove();
        const caret=document.createRange();caret.selectNodeContents(paragraph);caret.collapse(true);
        selection.removeAllRanges();selection.addRange(caret);savedRange=caret.cloneRange();
        queueSave();return;
      }
    }
    const task=element?.closest('ul.checklist > li');
    if(task&&editor.contains(task)&&e.key==='Enter'&&!e.isComposing&&!e.shiftKey){
      const range=selection?.rangeCount?selection.getRangeAt(0):null;
      if(range&&task.contains(range.startContainer)&&task.contains(range.endContainer)){
        e.preventDefault();e.stopPropagation();
        if(!selection.isCollapsed)range.deleteContents();
        if(!task.textContent.trim()){
          const paragraph=document.createElement('p');paragraph.append(document.createElement('br'));
          const list=task.parentElement;
          if(task.nextElementSibling){
            const following=document.createElement('ul');following.className='checklist';
            while(task.nextElementSibling)following.append(task.nextElementSibling);
            list.after(paragraph,following);
          }else list.after(paragraph);
          task.remove();if(!list.children.length)list.remove();
          const caret=document.createRange();caret.selectNodeContents(paragraph);caret.collapse(true);
          selection.removeAllRanges();selection.addRange(caret);savedRange=caret.cloneRange();
        }else{
          const tail=document.createRange();tail.selectNodeContents(task);
          tail.setStart(range.startContainer,range.startOffset);
          const fragment=tail.extractContents();
          fragment.querySelectorAll('input[type="checkbox"]').forEach(input=>input.remove());
          const next=document.createElement('li');
          const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.contentEditable='false';
          next.append(checkbox,document.createTextNode(' '),fragment);
          if(!next.textContent.trim())next.append(document.createElement('br'));
          task.after(next);
          const caret=document.createRange();caret.setStart(next,2);caret.collapse(true);
          selection.removeAllRanges();selection.addRange(caret);savedRange=caret.cloneRange();
        }
        queueSave();return;
      }
    }
    const codeBlock=element?.closest('pre');
    if(codeBlock&&editor.contains(codeBlock)&&e.key==='Enter'&&!e.isComposing){
      const range=selection?.rangeCount?selection.getRangeAt(0):null;
      const after=range?.cloneRange();
      after?.selectNodeContents(codeBlock);
      if(range)after?.setStart(range.endContainer,range.endOffset);
      const atEnd=!!range&&selection.isCollapsed&&!after?.toString();
      const before=range?.cloneRange();
      before?.selectNodeContents(codeBlock);
      if(range)before?.setEnd(range.startContainer,range.startOffset);
      const currentLine=(before?.toString()||'').split('\n').pop()||'';
      if(atEnd&&(currentLine.trim()===''||e.metaKey)){
        e.preventDefault();e.stopPropagation();
        const paragraph=document.createElement('p');paragraph.append(document.createElement('br'));
        codeBlock.after(paragraph);
        if(!codeBlock.textContent.trim())codeBlock.remove();
        const caret=document.createRange();caret.selectNodeContents(paragraph);caret.collapse(true);
        selection.removeAllRanges();selection.addRange(caret);savedRange=caret.cloneRange();
        queueSave();return;
      }
      e.preventDefault();e.stopPropagation();
      document.execCommand('insertText',false,'\n');queueSave();return;
    }
    if(codeBlock&&editor.contains(codeBlock)&&e.key==='Backspace'&&!codeBlock.textContent.trim()){
      e.preventDefault();e.stopPropagation();
      const paragraph=document.createElement('p');paragraph.append(document.createElement('br'));codeBlock.replaceWith(paragraph);
      const caret=document.createRange();caret.selectNodeContents(paragraph);caret.collapse(true);selection.removeAllRanges();selection.addRange(caret);savedRange=caret.cloneRange();queueSave();return;
    }
    if (slashOpen) {
      if (e.key==='Escape'){e.preventDefault();e.stopPropagation();closeSlashMenu();return}
      if (e.key==='ArrowDown'||e.key==='ArrowUp'){
        e.preventDefault();e.stopPropagation();
        if(slashMatches.length){slashSelected=(slashSelected+(e.key==='ArrowDown'?1:-1)+slashMatches.length)%slashMatches.length;renderSlashMenu();$('slashMenu').querySelector('.selected')?.scrollIntoView({block:'nearest'})}
        return;
      }
      if(e.key==='Enter'||e.key==='Tab'){
        if(slashMatches.length){e.preventDefault();e.stopPropagation();selectSlash(slashSelected);return}
        closeSlashMenu();
      }
      if(e.key==='ArrowLeft'||e.key==='ArrowRight'||e.key==='Home'||e.key==='End')closeSlashMenu();
    }
    if(e.key==='/'&&!e.metaKey&&!e.ctrlKey&&!e.altKey&&!e.isComposing&&!slashOpen){
      const prefix=slashPrefix();
      if(prefix&&prefix.text===''){
        e.preventDefault();e.stopPropagation();slashOpen=true;slashSelected=0;
        document.execCommand('insertText',false,'/');renderSlashMenu();return;
      }
    }
  });
  editor.addEventListener('keydown',e=>{const node=window.getSelection()?.anchorNode; const element=node?.nodeType===Node.ELEMENT_NODE?node:node?.parentElement;if(e.key==='Tab' && element?.closest('li')){e.preventDefault();command(e.shiftKey?'outdent':'indent')}});
  document.addEventListener('keydown',e=>{
    if(recordingId){recordShortcut(e);return}
    const browserOpen=!$('browser').classList.contains('hidden');
    const actionsOpen=!$('actions').classList.contains('hidden');
    const findOpen=!$('findBar').classList.contains('hidden');
    const linkOpen=!$('linkMenu').classList.contains('hidden');
    const formatOpen=!$('formatMenu').classList.contains('hidden');
    const renameOpen=!$('renameDialog').classList.contains('hidden');
    const overlayOpen=browserOpen||actionsOpen||findOpen||linkOpen||formatOpen||renameOpen;
    if(e.key==='Escape' && overlayOpen){e.preventDefault();closeOverlays();return}
    const printable=e.key.length===1 && !e.metaKey && !e.ctrlKey && !e.altKey;
    const typeInto=(input)=>{e.preventDefault();input.focus({preventScroll:true});input.value+=e.key;input.dispatchEvent(new Event('input',{bubbles:true}))};
    if(browserOpen && e.metaKey && e.key.toLowerCase()==='f'){e.preventDefault();$('search').focus();$('search').select();return}
    if(browserOpen) {
      if(e.key==='Tab' && !$('browser').contains(document.activeElement)){e.preventDefault();$('search').focus();return}
      if(printable && document.activeElement!==$('search') && !document.activeElement?.matches('button')){typeInto($('search'));return}
      if(document.activeElement===$('search') || document.activeElement?.classList.contains('note-row') || !$('browser').contains(document.activeElement)){
      if(e.key==='ArrowDown' || e.key==='ArrowUp'){e.preventDefault();moveLauncherSelection('browser',e.key==='ArrowDown'?1:-1);return}
      if(e.key==='Enter'){e.preventDefault();selectLauncherRow('browser');return}
      }
    }
    if(actionsOpen) {
      if(e.key==='Tab' && !$('actions').contains(document.activeElement)){e.preventDefault();$('actionSearch').focus();return}
      if(printable && document.activeElement!==$('actionSearch') && !document.activeElement?.matches('button')){typeInto($('actionSearch'));return}
      if(document.activeElement===$('actionSearch') || document.activeElement?.classList.contains('action-item') || !$('actions').contains(document.activeElement)){
      if(e.key==='ArrowDown' || e.key==='ArrowUp'){e.preventDefault();moveLauncherSelection('actions',e.key==='ArrowDown'?1:-1);return}
      if(e.key==='Enter'){e.preventDefault();selectLauncherRow('actions');return}
      }
    }
    if(findOpen){
      if(printable && document.activeElement!==$('findInput')){typeInto($('findInput'));return}
      if(e.key==='Enter' && (document.activeElement===$('findInput') || !$('findBar').contains(document.activeElement))){e.preventDefault();moveFind(e.shiftKey?-1:1);return}
    }
    if(linkOpen && printable && document.activeElement!==$('linkInput') && !document.activeElement?.matches('button')){typeInto($('linkInput'));return}
    if(!overlayOpen && printable && e.key!==' ' && document.activeElement!==editor && !document.activeElement?.matches('input,textarea')){
      e.preventDefault();editor.focus({preventScroll:true});
      const startSlash=e.key==='/'&&slashPrefix()?.text==='';
      if(startSlash){slashOpen=true;slashSelected=0}
      document.execCommand('insertText',false,e.key);queueSave();
      if(startSlash)renderSlashMenu();
      return;
    }
    const combo=eventShortcut(e); if (!combo) return;
    const action=actions.find(a=>shortcutFor(a)===combo); if (!action) return;
    if (!$('settings').classList.contains('hidden') && action.id!=='settings') return;
    if (action.editorOnly && document.activeElement!==editor && !editor.contains(document.activeElement)) return;
    e.preventDefault(); e.stopPropagation(); action.run();
  });
  window.addEventListener('beforeunload',flush);
  updateShortcutHints();
  syncGlobalShortcuts();
  showCurrent();
  notify('themeChanged', {theme});
  notify('glassChanged',{enabled:String(glass.enabled),strength:String(glass.strength)});
  notify('loadData');
  setInterval(() => { if (diskReady && !editorDirty) notify('loadData') }, 3000);
})();
