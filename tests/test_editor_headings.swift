import AppKit
import WebKit

final class HeadingCheck: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = #"""
        (() => {
          const editor = document.getElementById('editor');
          const results = [];
          function key(value) {
            editor.dispatchEvent(new KeyboardEvent('keydown', {key:value,bubbles:true,cancelable:true}));
          }
          function caret(node, offset) {
            const range = document.createRange();
            range.setStart(node, offset);range.collapse(true);
            const selection = window.getSelection();
            selection.removeAllRanges();selection.addRange(range);
            editor.focus();
          }
          for (const level of [1,2,3,4,5,6]) {
            editor.innerHTML = `<p>${'#'.repeat(level)}</p>`;
            const block = editor.firstElementChild;
            caret(block.firstChild, level);
            key(' ');
            results.push([`heading ${level}`, editor.firstElementChild?.tagName === `H${level}` && !editor.textContent.includes('#')]);
          }
          editor.textContent = '#';
          caret(editor.firstChild, 1);
          key(' ');
          results.push(['heading in empty editor', editor.firstElementChild?.tagName === 'H1']);
          editor.innerHTML = '<h1>Title</h1>';
          caret(editor.firstElementChild.firstChild, 5);
          key('Enter');
          results.push(['enter after heading', editor.children[0]?.tagName === 'H1' && editor.children[1]?.tagName === 'P']);
          editor.innerHTML = '<h2>Title and text</h2>';
          caret(editor.firstElementChild.firstChild, 5);
          key('Enter');
          results.push(['enter inside heading', editor.children[0]?.textContent === 'Title' && editor.children[1]?.tagName === 'P' && editor.children[1]?.textContent === ' and text']);
          editor.innerHTML = '<p>ordinary text</p>';
          caret(editor.firstElementChild.firstChild, 13);
          key(' ');
          results.push(['ordinary text unchanged', editor.firstElementChild?.tagName === 'P']);
          editor.innerHTML = '<pre>##</pre>';
          caret(editor.firstElementChild.firstChild, 2);
          key(' ');
          results.push(['code block unchanged', editor.firstElementChild?.tagName === 'PRE']);
          return results;
        })()
        """#
        webView.evaluateJavaScript(script) { value, error in
            if let error { fputs("WebKit heading test failed: \(error)\n", stderr); exit(1) }
            guard let results = value as? [[Any]] else { fputs("Missing heading test results\n", stderr); exit(1) }
            let failures = results.filter { ($0[1] as? Bool) != true }
            for item in results { print("\(item[0]): \((item[1] as? Bool) == true ? "ok" : "FAILED")") }
            exit(failures.isEmpty ? 0 : 1)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fputs("Could not load editor: \(error)\n", stderr)
        exit(1)
    }
}

guard CommandLine.arguments.count == 2 else { fputs("Usage: swift test_editor_headings.swift path/to/index.html\n", stderr); exit(2) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
let webView = WKWebView(frame: window.contentView!.bounds)
let check = HeadingCheck()
webView.navigationDelegate = check
window.contentView = webView
window.makeKeyAndOrderFront(nil)
let index = URL(fileURLWithPath: CommandLine.arguments[1])
webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
app.run()
