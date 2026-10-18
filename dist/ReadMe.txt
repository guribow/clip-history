ClipHistory

A clipboard history app.
Just copy as usual. ClipHistory keeps your text and images.
Press Shift-Command-V, pick an item, and it's pasted into the app you're using.

Requires macOS 13 or later (Apple silicon or Intel).
The app shows English or Japanese, following your Mac's language.


== Install ==

1. Move ClipHistory.app to the Applications folder.
2. Double-click ClipHistory.app.
3. If macOS says it can't open the app, click "Done".
   (This happens only the first time, because the app is not from the App Store.)
4. Open System Settings > Privacy & Security.
   Scroll down and click "Open Anyway", then enter your password.
5. Double-click ClipHistory.app again and click "Open".
6. Open System Settings > Privacy & Security > Device Control and Data Access
   and turn on ClipHistory. If it isn't in the list, click "+" and choose ClipHistory.app.
   On macOS 26 or earlier, this is called "Accessibility".
   Now you can paste with one click.

A clipboard icon appears in the menu bar. You're ready.
To start ClipHistory when you log in, click the icon, choose "Settings…"
and turn on "Open at login".


== How to use ==

- Keep: Just copy. Text and images are kept, newest first. Up to 200 items.
- Paste: Press Shift-Command-V, choose with the arrow keys and press Return.
  You can also double-click, or press Command-1 to Command-9.

More:
- Type in the list: filter text
- Point to an item, or right-click it: see the full text or a larger image
- Command-Delete in the list, or right-click > "Delete": delete the selected item
- Esc: close the list
- Icon > "Pause Recording": before you copy something private
- Icon > "Clear History…": delete all items
- Icon > "Settings…": shortcut, history size, open at login
- To see the version, click the icon > "About ClipHistory"
- When a new version is out, a small dot appears on the icon.
  Choose "Update to Version …" at the top of the menu to install it.


== About history and data ==

- Items that password managers mark as private are not kept.
- Without Device Control and Data Access, the item is only copied to the clipboard.
  Press Command-V to paste.
- After you install a new version, remove ClipHistory from
  Device Control and Data Access with "−" and turn it on again.
  If you install it from the zip, also repeat steps 3-5 of "Install".
  Steps 3-5 are not needed when you use "Update" in the menu.
- Your history is never sent outside your Mac.
- Once a day, the app asks GitHub for the latest version.
  You can turn this off with "Check for Updates Automatically" in the menu.


== Uninstall ==

1. Click the icon > "Quit".
2. Move ClipHistory.app in the Applications folder to the Trash.
3. To delete the history too, in Finder choose Go > Go to Folder…,
   enter ~/Library/Application Support/ClipHistory and move that folder to the Trash.


License: MIT (see LICENSE in this folder). No warranty.
Questions: https://github.com/guribow/clip-history/issues
