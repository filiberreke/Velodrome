# National flags — Countryflags.com

The 25 original, rectangular PNG flags in this folder are downloaded unchanged
from **Countryflags.com**, at medium resolution (960–1000 px wide). Original national
aspect ratios are retained, including Switzerland's square flag.

Retrieved: **2026-11-16**. Exact source pages, download URLs and SHA-256 checksums
are recorded per country in [sources.json](sources.json).

## External licence

These images are third-party assets under the
[Countryflags.com licence agreement](https://www.countryflags.com/license-agreement/)
(last updated 2026-09-16), rather than the repository's code licence.
The agreement permits worldwide, non-exclusive, royalty-free use in apps and
products, including commercial work and technical adaptation. Attribution is
normally optional; Velodrome credits Countryflags.com here. It prohibits reselling
the files as a download archive, building a competing flag database, implying
official endorsement, and unlawful uses. Local rules concerning national symbols
and other third-party rights still apply. See the full licence at the link above;
a text snapshot of the retrieved licence is in `license-source.txt`.

`res://national_flags.gd` supplies these same imported textures to rider passports,
team-pursuit opponent cards and `res://arena_flags.gd`. Unknown country IDs return
no flag instead of falling back to Australia. UI and stadium flags preserve the
source image ratio without cropping or stretching.

To refresh the assets and provenance, run `python tools/download_country_flags.py`
from the repository root. Requires network access; the game itself works offline.
