# Text Expansion — Phase 7 Manual Regression Matrix

Use this checklist before merging/releasing the text-expansion feature.

## Setup

Create these entries:

| Trigger | Replacement |
| --- | --- |
| dc | được |
| ss | Sun Santa |
| ph | phụ huynh |
| heart | ❤️ |
| sig | Harry Tran + newline + Sun Santa |
| long | a replacement longer than 100 characters |

Run the matrix once with Auto Caps OFF, then the marked cases with Auto Caps ON.

## Core behavior — Windows and macOS

- [ ] VI: `dc Space` -> `được `
- [ ] EN: `ss Space` -> `Sun Santa `
- [ ] `ss,` -> `Sun Santa,`
- [ ] `ss.` -> `Sun Santa.`
- [ ] `ss;` -> `Sun Santa;`
- [ ] `ph:` -> `phụ huynh:`
- [ ] `ss!` -> `Sun Santa!`
- [ ] `ss?` -> `Sun Santa?`
- [ ] `ss)` -> `Sun Santa)`
- [ ] EN / Simple Telex: `ss]` -> `Sun Santa]`
- [ ] EN / Simple Telex: `ss}` -> `Sun Santa}`
- [ ] `ss Enter` preserves Enter
- [ ] `ss Tab` preserves Tab
- [ ] `heart Space` inserts ❤️
- [ ] `sig Space` inserts both lines, then Space
- [ ] `long Space` inserts the full >32-character replacement

## Auto Caps

Enable “Tự viết hoa”.

- [ ] `dc` -> `được`
- [ ] `Dc` -> `Được`
- [ ] `DC` -> `ĐƯỢC`
- [ ] Mixed-case `dC` does not auto-match
- [ ] An explicit exact-case entry wins over Auto Caps

## Session / stale context

- [ ] Type `ss`, click another field, press Space: no expansion
- [ ] Type `ss`, press Left/Right/Home/End, then Space: no stale expansion
- [ ] Type `ss`, use Cut/Paste/Undo/Redo shortcut, then Space: no stale expansion
- [ ] Switch app after typing `ss`, press Space: no expansion
- [ ] Switch input source after typing `ss`, press Space: no stale expansion
- [ ] Open/close emoji picker after typing `ss`, press Space: no stale expansion

## Backspace / Auto Switch

- [ ] `sss Backspace Space` -> `Sun Santa `
- [ ] `ss Space Backspace` -> `Sun Santa` (only the boundary is removed)
- [ ] After expansion, type a normal English word: VI->EN Auto Switch still works
- [ ] After English-mode expansion, type a Vietnamese word: EN->VI Auto Switch still works
- [ ] Backspace after expansion never invokes AutoFixUndo for the expansion
- [ ] Existing AutoFixUndo behavior still works for real auto-switch corrections

## Vietnamese engine compatibility

- [ ] Normal Telex: `dd` -> `đ`
- [ ] Normal Telex: `aw` -> `ă`
- [ ] Normal Telex: `ow` -> `ơ`
- [ ] Tone placement still works
- [ ] Invalid-word restore still works
- [ ] Teencode still works
- [ ] Simple Telex 1 works
- [ ] Simple Telex 2 works
- [ ] Standard Telex: `]` / `}` still produce the configured ư/Ư behavior and are NOT stolen as expansion boundaries

## Safety / privacy

- [ ] Browser password field: no expansion
- [ ] macOS Secure Input: no expansion
- [ ] Password manager: no expansion
- [ ] Terminal / shell: no expansion
- [ ] Excluded app: no expansion
- [ ] Vikey’s own settings fields: no expansion
- [ ] Replacement text does not recursively trigger another expansion

## UI / persistence

### Windows
- [ ] Add / edit / delete
- [ ] Search
- [ ] Enable/disable
- [ ] English-mode toggle
- [ ] Auto Caps toggle
- [ ] Import OpenKey/UniKey
- [ ] Export OpenKey/UniKey
- [ ] Restart Vikey: entries persist
- [ ] Changes apply without restart

### macOS
- [ ] “Gõ tắt” tab fits the existing settings window
- [ ] Add / edit / delete
- [ ] Duplicate manual trigger shows an error
- [ ] Search
- [ ] Multiline editor
- [ ] Emoji copy/paste
- [ ] Enable/disable
- [ ] English-mode toggle
- [ ] Auto Caps toggle
- [ ] Import OpenKey/UniKey
- [ ] Export OpenKey/UniKey
- [ ] Restart Vikey: entries persist
- [ ] Changes apply without restart

## App matrix

### Windows
- [ ] Notepad
- [ ] Chrome
- [ ] Microsoft Word
- [ ] Microsoft Excel
- [ ] VS Code
- [ ] Zalo
- [ ] Messenger/Web Messenger
- [ ] Windows Terminal (must stay disabled)
- [ ] Browser password field (must stay disabled)

### macOS
- [ ] TextEdit
- [ ] Safari
- [ ] Chrome
- [ ] Microsoft Word
- [ ] Microsoft Excel
- [ ] VS Code
- [ ] Notes
- [ ] Zalo if installed
- [ ] Terminal (must stay disabled)
- [ ] Secure/password field (must stay disabled)

## Layout compatibility — macOS

- [ ] QWERTY
- [ ] Dvorak
- [ ] Colemak
- [ ] AZERTY

For each non-QWERTY layout, verify that the replacement is correct AND the original boundary key is replayed correctly.

## Pass criterion

Do not mark the feature release-ready until:
1. shared/engine automated checks pass,
2. Windows app builds,
3. macOS app builds,
4. the core manual matrix above passes on at least one real Windows machine and one real Mac.
