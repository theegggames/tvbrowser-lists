# tvbrowser-lists

Block lists for the **Wavrush TV Browser** Android TV app (Wavrush TV browser).

This repository is generated automatically. It holds the compiled ad and tracker block lists that the browser downloads, plus the scripts that build and sign them. It is public so that the app can download the files without signing in.

## What is here

| Path | What it is |
| --- | --- |
| `feed/manifest.json` | The current version number, the date and the checksum of the list file. |
| `feed/shields.dat` | The compiled block-list engine data used by the browser. |
| `feed/manifest.sig` | A digital signature over `manifest.json`. |
| `tools/` | The scripts that download the source lists, compile them and publish the result. |
| `.github/workflows/update-lists.yml` | The GitHub Action that runs the update every day. |


## Privacy

The browser fetches these files anonymously. This repository collects nothing about the people who download them, and the lists contain no personal data.

## Source lists and licenses

The block rules are derived from these community-maintained lists. All credit for the rules belongs to their authors and maintainers:

- **EasyList** and **EasyPrivacy** (the `easylist` project, <https://github.com/easylist/easylist>). Dual-licensed under GPL v3+ and CC BY-SA 3.0 or later.
- **uBlock Origin filter lists** (`uAssets`, <https://github.com/uBlockOrigin/uAssets>): filters, badware, resource abuse, annoyances, unbreak and privacy lists. Licensed under GPL v3.

The compiled data in `feed/` is a derivative of these lists, so it stays available under the same open terms. If you use it elsewhere, keep this credit and follow the licenses above.

The compiling engine, [adblock-rust](https://github.com/brave/adblock-rust) by Brave Software, is licensed under MPL 2.0.

The scripts in `tools/` and the workflow are the work of the Wavrush TV Browser project.

## Reporting a wrongly blocked site

If a site breaks because of a block rule, open an issue here with the site address and what stopped working. Rules that come from the lists above are best reported to their maintainers as well, since that fixes the problem for everyone.
