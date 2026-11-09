# Quiet Campus: local browser edition

[简体中文](web-user-guide.zh-CN.md)

A quiet place to keep everyday thoughts, experiences and project memories. This edition reuses the original Flutter app and saves an encrypted archive **in this browser, at this site origin**. No account is required. Cloud sync is not included. The existing Android and Windows clients retain their separate account and sync features; this guide describes the browser edition only.

## Where to open it

The development address, `http://127.0.0.1:7360/`, works only on the computer running the local server. It is not a public link or an address another phone can use. A stable HTTPS deployment needs separate approval; none has been published in this round.

Adding `?demo=1` opens clearly labelled fictional samples. **Demo changes reset on refresh.** Please do not enter private information there. Open the address without this parameter for your local archive. The top strip identifies which edition you are using.

Desktop Chrome and Edge are used during development. Full testing on physical phones is still pending. A narrow desktop viewport does not establish phone compatibility.

## Start your archive

1. Choose a unique archive passphrase of at least 12 characters and confirm it. Do not reuse your email password.
2. Download the recovery key, check that the file exists, and keep it safely offline. The recovery key and encrypted backup are different files; keep both safe.
3. Press the central **＋**, choose a journal, experience or project, then write and save. Open the original record to check it. After a refresh, unlock the archive again.

If a passphrase is wrong, edit it and try again without clearing data. If every unlock method is lost, the developer cannot recover your writing. Never send your passphrase, recovery key or private backup to support.

## Write and find things again

- Write directly in the rich-text editor. Shortcuts such as `# ` and `- ` format new input; the formatting help lists supported markers. Rich text remains in the original Delta format.
- Open **Tags and links** to create a tag with `#` or reuse a previous one. Tag management stays within Notes. Renaming updates associations; removing a tag keeps the writing and attachments.
- Search titles, writing, tags and record types together. Matching normalizes text and looks for characters in order, including spaced-out and repeated matches. It is not semantic search or spelling correction. Types follow the display language; English mode also accepts their original Chinese aliases.
- The list shows 20 records at a time. Search and **Export all notes** cover every record loaded by the client, not just the visible batch. This is not server pagination.
- Yue the rabbit offers a local, rule-based response, not a language-model interpretation. Open a record for the original writing. Responses, gestures and search highlights do not alter or appear in the original Delta or notes export.
- Use **English / 中文** at the top to change the interface language. Your writing and tags are not translated. Language changes should preserve an open draft; save before leaving the page, closing the tab or refreshing.

The material library stores originals that several notes can reference. Voice recording keeps the sound without online transcription and needs your microphone permission. Schedule dates use the device’s local day. Calendar export requires your confirmation and excludes journal text by default. Background notifications after closing the page are not promised.

## Back up and restore

1. Open **Archive → Settings → Export encrypted backup**. Check the downloaded file and store it safely elsewhere. A download message is not proof of safekeeping. Limits: 64 MiB for the complete encrypted snapshot, 20 MiB per attachment, and 2 MiB for one record’s encrypted envelope.
2. In a separate browser profile or isolated site origin, choose **Restore an encrypted backup**. Enter that backup’s own passphrase or recovery key, validate it and review the counts of archive objects, attachments and unresolved versions.
3. Confirm the whole-archive replacement. There is no implicit merge. If the destination already has data, export its complete backup first, check that the file is safely stored, then tick the confirmation. A download request alone does not unlock replacement. After restoring, open a record and check its attachments. Restoring the identical snapshot again does not add duplicate records.

**Export all notes** creates unencrypted JSON; the single-record text export is also unencrypted. Neither includes all original material files. Use the encrypted backup for a complete archive. Search highlights are never exported.

Damaged, oversized or unsupported backups should be rejected without overwriting existing data. If reading storage fails, keep the site data and browser installation. Preserve any readable backup and test recovery in isolation first. The app does not reset the database automatically.

## What local storage means

Changing the domain, port, browser profile or device does not transfer your archive. Private browsing, browser cleanup and storage eviction can lose data. Back up regularly and verify a restore before changing your entry address. This edition offers neither automatic backups nor a guarantee against data loss.

If two tabs edit the same archive, an outdated write is rejected. Copy unsaved input, export a readable backup, then reopen the latest archive. Clearing site data is not a repair procedure.

This browser edition does not use online AI, advertising analytics or an account backend. Unlocking keys stay in session memory and must be entered again after locking. A compromised browser, device or malicious app update remains a security boundary.

No public sale or payment has taken place in this round. The final product name, author, license, update scope and support contact require the owner’s confirmation. No lifetime cloud storage or permanent human support is included.
