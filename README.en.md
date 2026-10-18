# ClipHistory

[日本語](README.md)

A clipboard history app in the menu bar.

Just copy as usual. ClipHistory keeps your text and images.
Press Shift-Command-V, pick an item, and it's pasted into the app you're using.
With Universal Clipboard, things you copy on your iPhone are kept too.

- Requires macOS 13 or later (Apple silicon or Intel).
- English and Japanese. The app follows your Mac's language.

## Download and install

Download the zip from [Releases](https://github.com/guribow/clip-history/releases/latest).
`ClipHistory-<version>-en.zip` has an English guide, `-ja.zip` has a Japanese guide. The app is the same.

1. Open the zip and move ClipHistory.app to the Applications folder.
2. Double-click it. If macOS says it can't open the app, click "Done".
   (This happens only the first time, because the app is not from the App Store.)
3. Open System Settings > Privacy & Security, scroll down, click "Open Anyway" and enter your password.
4. Double-click the app again and click "Open".
5. To paste with one click, turn on ClipHistory in System Settings > Privacy & Security > Device Control and Data Access.
   If it isn't in the list, add it with "+". On macOS 26 or earlier, this is called "Accessibility".

A clipboard icon appears in the menu bar. After you install a new version, remove ClipHistory from Device Control and Data Access with "−" and turn it on again. If you install it from the zip, repeat steps 2-4 first. Steps 2-4 are not needed when you use "Update" in the menu.
Then remove ClipHistory from Device Control and Data Access with "−" and turn it on again.

## How to use

- **Keep:** Just copy. Text and images are kept, newest first. Up to 200 items.
- **Paste:** Press Shift-Command-V, choose with the arrow keys and press Return.
  You can also double-click, or press Command-1 to Command-9.
- **Find:** Type in the list to filter text.
- **View:** Point to an item in the list, or right-click it, to see the full text or a larger image.
  This also works for the items in the menu bar menu.
- **Delete:** Select an item and press Command-Delete, or right-click it and choose "Delete".
  To delete all, click the menu bar icon and choose "Clear History…".
- **Pause:** Before you copy something private, click the menu bar icon and choose "Pause Recording".
- The menu bar icon also shows the last 10 items.
- In "Settings…", you can change the shortcut, the history size and "Open at login".
- When a new version is out, a small dot appears on the menu bar icon. Choose "Update to Version …" at the top of the menu to install it and restart.

## About history and data

- Items that password managers mark as private are not kept.
- Without Device Control and Data Access, the item is only copied to the clipboard. Press Command-V to paste.
- History is saved in `~/Library/Application Support/ClipHistory`. It is never sent outside your Mac.
- Once a day, the app asks GitHub for the latest version. You can turn this off with "Check for Updates Automatically" in the menu. The app sends no other data.

## Uninstall

1. Click the menu bar icon > "Quit".
2. Move ClipHistory.app to the Trash.
3. To delete the history too, move `~/Library/Application Support/ClipHistory` to the Trash.

## Build from source

Requires Xcode (swiftc).

```bash
./build.sh   # build and install to ~/Applications/ClipHistory.app
./dist.sh    # make zips in dist/
./test.sh    # run the tests
```

## License

MIT License ([LICENSE](LICENSE)). No warranty.
