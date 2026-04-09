# Hyprcapture

A simple tool which tracks application usage for hyprland. Takes in one cmdline
argument, the path to an sqlite database file.

## Usage

### Running the program

```bash
~ ❯ hyprcapture ./hyprcapture.sqlite
```

### Print out the table as json

I use [jq](https://jqlang.org/) here for nice foramtting.

```bash
~ ❯ sqlite3 -json hyprcapture.sqlite "SELECT * FROM usage;" | jq
[
  {
    "class": "nvim",
    "title": "backend",
    "date": "2026-04-09",
    "duration": 2434250000000
  },
  {
    "class": "firefox",
    "title": "WhatsApp — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 726400000000
  },
  {
    "class": "firefox",
    "title": "Mayu Killa | Organic House ~ Andean Downtempo ~ Tribal Flow ~ World Fusion - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 3100000000
  },
  {
    "class": "firefox",
    "title": "I will persist until success. / Jazzy Lo-fi Beats for Study, Focus - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 33350000000
  }
]
```

### Print out the table as json with second duration instead of nanosecond

```bash
~ ❯ sqlite3 -json hyprcapture.sqlite "SELECT class, date, title, duration / 1e9 AS duration FROM usage;" | jq
[
  {
    "class": "nvim",
    "date": "2026-04-09",
    "title": "backend",
    "date": "2026-04-09",
    "duration": 2434.25
  },
  {
    "class": "firefox",
    "date": "2026-04-09",
    "title": "WhatsApp — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 726.4
  },
  {
    "class": "firefox",
    "date": "2026-04-09",
    "title": "Mayu Killa | Organic House ~ Andean Downtempo ~ Tribal Flow ~ World Fusion - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 3.1
  },
  {
    "class": "firefox",
    "date": "2026-04-09",
    "title": "I will persist until success. / Jazzy Lo-fi Beats for Study, Focus - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 33.35
  }
]
```

### Print out the table as json with minute duration instead of nanosecond and sort it

```bash
~ ❯ sqlite3 -json hyprcapture.sqlite "SELECT class, title, date, duration / 60e9 AS duration FROM usage ORDER BY duration DESC;" | jq | bat -ljson
[
  {
    "class": "nvim",
    "title": "backend",
    "date": "2026-04-09",
    "duration": 40.570833333333333
  },
  {
    "class": "firefox",
    "title": "WhatsApp — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 12.106666666666667
  },
  {
    "class": "firefox",
    "title": "Everybody is vendoring their dependencies, so should you - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 8.35
  },
  {
    "class": "firefox",
    "title": "GitHub's leadership Change - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 3.9241666666666668
  },
  {
    "class": "nvim",
    "title": "hyprcapture",
    "date": "2026-04-09",
    "duration": 2.0016666666666665
  },
  {
    "class": "footclient",
    "title": "foot",
    "date": "2026-04-09",
    "duration": 1.6083333333333334
  },
  {
    "class": "lazygit",
    "title": "lazygit",
    "date": "2026-04-09",
    "duration": 1.0491666666666666
  },
  {
    "class": "firefox",
    "title": "I will persist until success. / Jazzy Lo-fi Beats for Study, Focus - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.55583333333333329
  },
  {
    "class": "footclient",
    "title": "Yazi: ~/Projects/forfun/hyprcapture",
    "date": "2026-04-09",
    "duration": 0.42083333333333334
  },
  {
    "class": "firefox",
    "title": "YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.315
  },
  {
    "class": "tpopup",
    "title": "btop",
    "date": "2026-04-09",
    "duration": 0.275
  },
  {
    "class": "firefox",
    "title": "(1) WhatsApp — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.20666666666666667
  },
  {
    "class": "firefox",
    "title": "Odin Programming Language — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.1925
  },
  {
    "class": "firefox",
    "title": "Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.1575
  },
  {
    "class": "org.pwmt.zathura",
    "title": "Sales brochure.pdf",
    "date": "2026-04-09",
    "duration": 0.10166666666666667
  },
  {
    "class": "tpopup",
    "title": "rmpc",
    "date": "2026-04-09",
    "duration": 0.078333333333333338
  },
  {
    "class": "footclient",
    "title": "Yazi: ~/",
    "date": "2026-04-09",
    "duration": 0.054166666666666669
  },
  {
    "class": "firefox",
    "title": "Mayu Killa | Organic House ~ Andean Downtempo ~ Tribal Flow ~ World Fusion - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.051666666666666666
  },
  {
    "class": "firefox",
    "title": "Always vendor your dependencies - YouTube — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.018333333333333333
  },
  {
    "class": "firefox",
    "title": "Proton Mail — Mozilla Firefox",
    "date": "2026-04-09",
    "duration": 0.0016666666666666668
  }
]
```
