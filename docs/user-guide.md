# Disinformation Labs™ user guide

A separate macOS SwiftUI companion to Syndrome, with an offline studio and an on-demand news research feed. It operates independently of the Syndrome sound studio.

The app combines a Richard Doty themed dossier archive with a fictional memorandum studio. A dark charcoal workspace, lime accents, and a blue alien emblem sit alongside aged-paper document previews.

## Open the app

Double-click `dist/Disinformation Labs.app`, or run:

```sh
./scripts/build-app.sh
open "dist/Disinformation Labs.app"
```

Requires macOS 14 or later. The build script needs Apple's Swift Command Line Tools (`xcode-select --install`). It creates an app for the current Mac's architecture and signs it locally with an ad-hoc signature. This is a local build, not a notarized distribution.

To regenerate the app icon from its SwiftUI vector source, run `zsh scripts/build-icon.sh` before building. The PNG preview is saved to `output/brand/output.png`.

For development, open `Package.swift` in Xcode or use `swift run DisinformationWorkshop`. No third-party packages or API keys are required.

## Dossier archive

- Six dossiers across Alien retrieval, UFO deception, and Paranormal psyops.
- Case-insensitive, multi-term search; category and bookmark filters.
- Briefings distinguish sourced context, unverified claims, and fictional scenarios.
- Per-record source links, locally saved analyst notes, and bookmarks.
- Study memo tab with interactive word redaction.
- **Open in workshop** creates an editable fictional study memo from a dossier.

The dossier archive distinguishes historical source material from unverified claims and fictional examples. “Ghost Dance” is explicitly fictional. The included memo bodies are original teaching exercises, not claimed government transcripts.

Primary context references:

- [FBI Vault / Unexplained Phenomenon](https://vault.fbi.gov/unexplained-phenomenon/search): the archive summary reports the purported MJ-12 memo was found fake by an Air Force investigation.
- [FBI Vault / Majestic 12](https://vault.fbi.gov/Majestic%2012): collection entry.
- [CIA / Did CIA really study psychic powers?](https://www.cia.gov/stories/story/ask-molly-did-cia-really-study-psychic-powers/): historical account of remote-viewing research and its operational limitations.

These sources do not authenticate the archive's disputed Doty-specific allegations. Source links open externally when clicked. The news observatory makes a network request only when you press Refresh national feed; other editing and geographic controls work locally.

## Workshop

Create, search, duplicate, or delete local drafts. Edit title, recipient, reference, letterhead, and up to 30,000 body characters. Choose typewriter, thermal fax, or third-generation photocopy styling; adjust aging/grain and word redaction; switch to a paginated US Letter preview.

**Export memo** saves a PDF or plain-text copy via the native macOS save panel. The preview and PDF use the same native page renderer. All PDF pages and text exports carry visible fictional-simulation provenance. PDF body content is paginated; title, recipient, and reference are single-line display fields and long values are ellipsized on the paper (the saved draft and text export retain them).

Redaction replaces selected body words with `[REDACTED]` before rendering or export. It does not redact the document title, recipient, reference, saved source draft, or workspace backup. Grain is deterministic so preview and export have matching texture. The UI shows one page at a time with previous/next controls.

Keyboard shortcuts: **⌘N** new memorandum, **⌘F** focus current search, **⇧⌘E** export PDF while viewing a preview.

## Local storage and backups

Drafts, notes, and bookmarks save to:

```text
~/Library/Application Support/SyndromeDisinformationWorkshop/workspace.json
```

Storage is independent of the original Syndrome app. Saves use atomic file replacement. Save failures appear in an alert and the footer. If an existing file is unreadable, the app preserves it and disables writing to it until a valid backup is imported; the unreadable file is copied aside before recovery.

Use the toolbar's drive menu to **Export workspace backup** or **Import workspace backup**. Import merges drafts; colliding draft IDs get a fresh ID. Bookmarks are combined and differing notes are appended. It does not replace the current collection. A backup contains editable, unredacted draft text.

## Build and validation

```sh
./scripts/test.sh
./scripts/build-app.sh
```

The standalone model checks work with Command Line Tools, without XCTest. Native smoke checks test multipage PDF generation in all three media, per-page provenance, final-paragraph retention, absent redacted text, and persisted draft/note/bookmark behavior. Test PDFs are written under `output/pdf/`.

Source organization:

- `WorkshopCore`: serializable models, seed dossiers, search, redaction, and atomic workspace storage.
- `DisinformationWorkshop`: SwiftUI screens, state store, AppKit document rendering, PDF export, and native smoke checks.
- `WorkshopChecks`: deterministic model checks.

The blue alien emblem is rendered from the SwiftUI vector source bundled in this repository.


## News observatory and outward radius search

Start in **News feed**, with **United States / Albuquerque, NM** selected on a fresh workspace. Choose a country, then press **Refresh national feed** to download only that country’s English-language Google News RSS snapshot. The default topic is blank (top headlines); an optional topic and 24-hour/7-day/30-day period can be applied with a refresh. Country editions can include international headlines and is not a complete national or local news database. Unknown publication dates are retained as unknown.

Each country’s national parent is fetched on demand and cached; switching cities, filtering, choosing a reference, turning the radius dial, and calculating similarity do not fetch anything. Only headline, publisher, URL, and publication-date metadata are downloaded. Full articles open through Google News in the user's browser. No article-body scraping, image downloads, GPS access, automatic refresh, or background monitoring is added. Requests time out after 25 seconds, are capped at 5 MB, and cannot be repeated within 10 seconds. Failed or cancelled refreshes preserve the prior snapshot.

**City** shows cached headlines mentioning the selected city's name. **National** shows the parent snapshot. **Saved** shows bookmarked reviews. **Radius** searches for city/place names in headlines within 10–1,000 miles of the selected center, excluding the seed article. Select a headline and press **Use as similarity seed**, then turn the dial or use its slider/stepper to widen the search. The city, topic, period, seed, and radius persist per country across launches.

The radius is measured between representative catalog place coordinates, not article-reported event locations. Place-name matching is literal and case/diacritic-insensitive with word boundaries; it cannot disambiguate every similarly named place or recognize aliases. A headline mentioning “Paris” could match the wrong Paris. Matching locations remain visibly unverified. Articles without a named matching place cannot appear in the geographic view, even if locally relevant. An empty view means no matching metadata in the cached sample, not that a city has no news. National top headlines typically contain fewer than 100 articles. Optional topic searches are also capped at 100 unique articles.

For the United States, the searchable city dropdown includes **32,350 entries from the 2025 US Census National Places Gazetteer**: cities, towns, villages, and census-designated places in the 50 states, DC, and Puerto Rico. It is bundled in the app, so typing or selecting a city makes no network request. Search results show the first 150 matches; narrow by state or name to reach any entry. It does not include every informal neighborhood or unincorporated locality. Source: [Census Gazetteer files](https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.2025.html), [downloaded national file](https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2025_Gazetteer/2025_Gaz_place_national.zip). The original GEOID, state code, and centroid coordinates are retained.

### Country selection (1.3)

Supported English editions: **United States, United Kingdom (including Northern Ireland), Canada, Australia, New Zealand, Ireland, India, Singapore, and South Africa**. A country edition is a regional news selection, not a guarantee that every article concerns that country or that every publisher is domestic. Google documents [language and region selection](https://support.google.com/googlenews/answer/7688469?co=GENIE.Platform%3DDesktop&hl=en).

Selecting a country switches immediately to its saved cache and local context, or an empty view if that country has never been refreshed. It makes no network request and never displays another country’s cache under the new country’s label. **Refresh national feed** requests only the selected edition; there is no global feed or background prefetch. Switching during a refresh cancels the prior request and rejects late results. A response with a different RSS language/edition is rejected. Refresh limits remain 25 seconds, 5 MB, and at least 10 seconds between attempts.

City pickers show only the selected country’s catalog, with region filters. Radius matches and neighboring-place suggestions stay inside that country even near a border. Saved reviews and reference choices are scoped by country; US review keys remain compatible with earlier archives. News similarity controls work the same way in every country. **New study country** creates a five-place study in that country; an existing study retains its own country and references when the news country changes.

The international catalog adds **23,638 places** in a bundled 1.27 MB TSV file:

| Country | Places | Initial city |
| --- | ---: | --- |
| United Kingdom | 5,918 | London |
| Canada | 3,297 | Toronto |
| Australia | 4,901 | Sydney |
| New Zealand | 732 | Auckland |
| Ireland | 566 | Dublin |
| India | 7,114 | New Delhi |
| Singapore | 121 | Singapore |
| South Africa | 989 | Cape Town |

International names, administrative regions, coordinates, and IDs are adapted from the [GeoNames cities500 and administrative-region datasets](https://download.geonames.org/export/dump/readme.txt), under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The source covers places with population over 500 or qualifying administrative seats; it is not every locality. ASCII names are used for the English picker. No aliases or event geocoding are inferred. The US catalog remains the 32,350-place Census dataset. The app downloads neither catalog at runtime. `scripts/build-international-places.py` rebuilds the international subset; source URLs, checksum, and per-country counts are in `docs/international-places-build.json`.

The RSS feed attributes articles to their publishers and Google News. Its stated use is personal, noncommercial feed reading. The app uses its public feed endpoint, not an authenticated Google API; endpoint availability and format can change.

### Confidence and verification ranking

Each article has an analyst-reviewed vector **[P, C, X, G]**: provenance, independent corroboration, context, and geographic relevance. Each dimension is Unreviewed, Weak (0), Partial (0.5), or Strong (1). Notes and supporting links are editable. Reviews are scoped to the article and selected city, so a geographic review does not transfer automatically to another city.

- **Evidence confidence** appears only after all four dimensions have been reviewed. It is their equal-weight average × 100, rounded. It is an analyst rubric, not a calibrated truth probability or automated fact check.
- **Verification priority** is `25 × sum(1 − dimensionValue)`, using 0 for an unreviewed dimension. Unknown or weak evidence therefore contributes 25, partial 12.5, and strong 0. Unknown is work to do, not evidence of falsehood. The interface explains each contribution.
- Standard lists can sort by verification priority, newest publication, or evidence confidence. Unknown confidence sorts last. Ties use publication date, then a stable ID.
- Radius results with a seed use the configurable lexical index below, then distance. Passing matches appear before weak matches when inspection is enabled. No semantic/LLM score, influence score, campaign viability score, or probability of a shared event is computed.

### Similarity calibration (1.2)

Open **Similarity** in the news feed or a study to inspect why two headlines match. The comparison pad accepts editable examples without changing saved articles. The inspector displays shared and excluded terms, shared adjacent phrases, and terms unique to each headline.

The index combines three values, each on a 0–1 scale:

- **K · Keywords (60% default):** shared content keywords divided by their union.
- **P · Adjacent phrases (30%):** shared two-word phrases divided by their union. Only original adjacency counts; removed words never create new phrases. If neither headline contains an eligible phrase, P is unknown and its weight is omitted.
- **C · Seed coverage (10%):** shared keywords divided by seed keywords. This is directional: reversing the seed can change C and the index. Study comparisons run from the first listed city to the second.

Available weights are normalized before calculating the index. All weights at zero, or a headline with no remaining content, produces an unknown index. Tokens are lowercase, diacritic-normalized alphanumeric words. Function words, generic reporting language, standalone numbers, and single-character tokens are excluded. Selected comparison place names and state codes are excluded by default; the engine does not recognize every location in a headline. Additional ignored words are configurable.

Conservative defaults require **two meaningful shared terms and an index of at least 40/100**. A difference in detected negation/denial wording also excludes a match by default. This is a simple wording flag, not semantic contradiction detection. Weak matches are hidden in seeded radius results unless **Show weak matches for inspection** is enabled. Distance, publication time, and evidence confidence do not increase the textual index.

Weights, minimum score, minimum shared terms, exclusions, and weak-match visibility are adjustable. News feed settings and each study's settings persist independently. An explicit one-word theme can match one term; headline-to-headline comparisons retain the configured minimum. A blank theme remains unknown.

These rules reduce specific lexical false positives but cannot establish that two stories are related. They do not recognize synonyms or resolve ambiguous meanings, negation scope, or event identity. Inspect the source articles before drawing conclusions.

### Multi-city studies

**Multi-city studies** starts with five US places (Albuquerque, Santa Fe, Roswell, Las Cruces, and Phoenix) and a blank theme. Create multiple studies, add or change places from the selected country’s dropdown, and compare **2–12 cities**. Each city can retain a reference article from that country’s national cache, saved reviews, or existing studies. Changing a city's identity clears that slot's reference so geographic assumptions are reconsidered.

The theme is an optional search vector; blank produces no theme score. Reference selection lists city-name matches first, then passing lexical index with the theme. Assignments are analyst choices, not evidence that the article describes that city or a shared event. Reusing one article in several cities is flagged and counted once.

The neighbor panel has a center selector and radius dial; it lists the nearest eight catalog places within range that are not already in the study, with buttons to add them. Pairwise vectors separately show keyword, phrase, and seed-coverage values, catalog-coordinate distance in miles (great-circle/Haversine), and absolute publication-date gap in hours. Missing articles or timestamps remain unknown. Publication dates are not incident times. The app does not infer a suspect, cause, route, coordinated activity, or single sighting from these metrics.

Study notes and references autosave. **Export study** writes a text report with source URLs, comparisons, and interpretation limits. This is a research/clearly fictional study board, not a tool for presenting invented threats or links between real incidents as factual reporting.

### News storage and archives

News data is separate from the original dossier workspace:

```text
~/Library/Application Support/SyndromeDisinformationWorkshop/news.json
```

It contains the active national snapshot, per-country caches and city/topic/seed/radius settings, similarity settings, reviews and notes, and multi-city studies. Archives without country fields remain US workspaces. Older archives without similarity settings load conservative defaults. Imported studies retain their own settings; importing does not replace the current global similarity settings. The toolbar drive menu has separate **Export news & studies archive** and **Import news & studies archive** actions; the older workspace backup covers dossier notes and fictional memos only. News import merges studies and reviews; existing assessments are retained and conflicting imported assessments are appended to notes. The current parent feed is preserved if already present. Previously uncached country feeds are merged without replacing existing caches or active country settings. Invalid archives are rejected, and unreadable local files are preserved before recovery.

Run the additional optional network integration check with:

```sh
swift run WorkshopChecks --live-news GB
```

The optional ISO country code defaults to US. This downloads one national feed; ordinary test runs use deterministic fixtures.




## Regional coverage heat map (1.4)

Open **Coverage map** in the sidebar. The view uses only the active country's cached headline snapshot; it performs no feed requests, map-tile downloads, geocoding calls, or audience-data collection. Choose a country, optionally filter headline text (for example, `election`) and publisher, then select a map marker or region row to inspect its articles. Refresh a country's cache from **News feed** as before.

The heat measures **distinct article URLs per state/region in the selected sample**, with a relative scale from zero to the current maximum. Marker size and intensity increase with article count. Publisher counts and manual tone-label counts accompany the regional groups. These are neither readership figures nor viewer sentiment, voter opinion, intended audiences, or population-normalized measures. A small national feed is not representative regional media coverage. A zero means no matching articles in this cache and filter, not no news or no interest in that region.

The map draws bundled country outlines locally. Region markers sit at the average coordinates of that region's catalog places (circular mean for longitude); they are not administrative boundaries, population centers, reported incident locations, or reader locations. Zoom focuses on a selected region. The region list remains available for small or overlapping markers.

**Include suggested locations** is on by default. Suggestions use complete regional names and city names that map to only one region in the selected country's catalog. Complete names take precedence over nested names. Common ambiguous place words are excluded. Single-word city suggestions also require a preceding “in”, “near”, or “around”, and known country names are excluded from that city rule. This deliberately favors fewer false matches over complete recall; analysts can assign missed locations manually. Suggestions can still be wrong: a headline can mention a place in passing or refer to another country. Suggestions are visibly labeled and counted separately. Disable them to view only analyst-assigned regions. No location is inferred from a reader, publisher domain, IP address, or demographic profile.

Select an article to manually annotate **tone** (Descriptive, Concerned/critical, Optimistic/approving, Mixed) and **format** (Reporting, Analysis, Opinion, Satire). Both begin Unreviewed. These labels describe the analyst's reading of published text, not reader response, factual correctness, or political alignment. Open the source to assess the full text. Notes preserve the reasoning. Tone labels are shown as categorical counts, not averaged into a purported sentiment score.

Under **Review region assignments**, explicitly assign regions, accept headline suggestions, mark an article unmapped, or reset it to unreviewed. An article may belong to several regional groups but counts only once within each; regional totals are not additive. Unmapped articles remain accessible. Annotation records are scoped to article and country, stored in the existing news archive, and survive cache changes. The map itself remains restricted to the active snapshot. News archive imports add previously missing annotations and retain existing ones on conflict.

**Export review** writes the current filtered regional groups with publisher labels, tone/format annotations, notes, source URLs, cache timestamp, filter settings, and interpretation limits. **Export news & studies archive** also includes the annotation records. Older archives without coverage annotations open normally.

Offline country outlines are adapted from [Natural Earth](https://www.naturalearthdata.com/), whose map data is [public domain](https://www.naturalearthdata.com/about/terms-of-use/). The bundled subset is approximately 397 KB. Build script: `scripts/build-coverage-outlines.py`; source checksum: `docs/coverage-outlines-build.json`. Catalog and outline credits are included in the app's resource bundle.


## Publication projects, visibility, and sprawl (1.5)

Open **Publication projects** and create a project. Register your published article URLs, then use **Record analytics** and **Record mention**. This is a local publication and evidence ledger: it does not publish content, crawl for mentions, fetch analytics, or monitor the web in the background. Site analytics and linked mentions are entered manually until a specific provider integration or export format is supplied.

Each project stores its title, notes, archive status, registered publications, mention observations, and analytics history. Publications retain a title, URL, optional publication date, editorial status (Published/Corrected/Retracted), and notes. Their URL is fixed after registration to preserve linked record identity. A new URL is a separate publication. Archiving preserves the project and its evidence.

**Visibility** is shown as separate observed quantities:

- Registered publication URLs are deduplicated.
- Reported page views use the **latest cumulative/all-time measurement per canonical publication URL**. Earlier snapshots remain in history but are not added together. Zero is a recorded value; absent analytics remain unknown. The dashboard shows how many URLs have measurements. Totals may be partial and have different as-of dates. Page views are not unique readers; daily counts and unique-visitor counts must not be entered into this field.
- External mentions count distinct analyst-confirmed URLs with relationship-evidence notes. Link/citation, republication, and discussion are separate record types. Unreviewed and rejected observations stay in history but do not count. Registered publication hostnames (including their `www` alias) are excluded from external counts. Distinct hostname counts are not counts of independently owned outlets.

URL canonicalization removes fragments and common tracking parameters, normalizes hostname/scheme and default ports, and sorts query items. It does not fetch redirect destinations or infer that different URLs contain the same article. Record the final source URL when known.

**Sprawl index** is a transparent project metric for the regional dispersion of documented publication/source locations:

```text
Sprawl = 100 × (1 − Σ regionalShare²)
regionalShare = qualifying external URLs in that country/region ÷ all qualifying external URLs
```

One represented region scores 0; two equally represented regions score 50; four score 75. With no qualifying geographic observations the index is Unknown. A high value indicates more even regional dispersion within this observed sample; it does not estimate reach, influence, audience demographics, truth, or comprehensive web spread. It is an app-defined descriptive index, not an industry benchmark or calibrated probability. Small samples can yield high values; the qualifying count is always shown.

Geography requires both an analyst-confirmed relationship and an explicitly documented source locality, with separate location-evidence notes. Enter the outlet/publication locality supported by a masthead, address, or equivalent evidence, rather than a place mentioned in the article or an inferred reader location. A confirmed URL with unknown geography still counts in visibility but not sprawl. Duplicate URLs with conflicting confirmed localities are excluded from geographic calculations. The dashboard shows geographic evidence coverage, distinct places, country/region groups, countries, and maximum source-place distance separately.

The project map uses the existing offline outlines and region markers, colored by qualifying external URL count for the selected map country. The index covers all countries represented in the project's recorded geography. Source-locality support currently follows the app's nine-country catalog. The list of observations remains available alongside the map.

**Export** writes the project's publication records, analytics history, linked evidence, source-location rationale, metric definitions, and interpretation limits to a text report. The news/studies archive also includes publication projects. Older archives without projects remain valid. Imports preserve existing projects; a colliding imported project receives a new project ID while retaining the internal links among its records.

## FOIA-style mockups (1.6.0)

Open **Workshop → New FOIA mockup**. You can also switch an existing draft's **Document layout** to **FOIA mockup**. Fill in the title, reference, recipient, fictional records office, record date, and mock release date. Dates are editable text for the fictional record. Add a simulated withholding label and choose whether to include an archive cover sheet.

Choose typewriter, fax, or photocopy styling, then adjust aging and redaction. **Preview** uses the same page renderer as **Export mockup → Export PDF**. Text export is also available. Metadata is saved with each draft; switching back to Memorandum preserves the FOIA settings for later use.

Every page carries fixed **FOIA MOCKUP / FICTIONAL SIMULATION** and **NOT AN AUTHENTIC GOVERNMENT RECORD** labels, a watermark, a `SIM-` record identifier, and page numbering. Release status is derived from the redaction setting. These are original fictional documents, not modified FOIA source PDFs or authenticated releases.

Black bars replace body words before PDF layout; original withheld words are absent from the exported text layer. The redaction slider is a deterministic visual treatment, not a manual word-selection tool. Titles, dates, reference IDs, and other metadata remain visible. Editable drafts and workspace backups retain the original text.
