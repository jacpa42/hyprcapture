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

### Print out usage data for a specific app

```bash
~ ❯ sqlite3 hyprcapture.sqlite "
    SELECT
      ROUND(SUM(duration) / 3600e9, 3) AS total_hours,
      COUNT(*) AS total_days_active,
      ROUND((SUM(duration) / 3600e9) / COUNT(*), 3) AS avg_hours_per_day
    FROM usage
    WHERE date = CURRENT_DATE;
    "
╭─────────────┬───────────────────┬───────────────────╮
│ total_hours │ total_days_active │ avg_hours_per_day │
╞═════════════╪═══════════════════╪═══════════════════╡
│       24.16 │                17 │             1.421 │
╰─────────────┴───────────────────┴───────────────────╯
```

### Get the usage data over a couple days

```bash
~ ❯ sqlite3 hyprcapture.sqlite "
    SELECT
      date,
      ROUND(SUM(duration) / 3600e9, 3) AS total_hours
    FROM usage
    GROUP BY date
    ORDER BY SUM(duration) DESC;
    "
╭────────────┬─────────────╮
│    date    │ total_hours │
╞════════════╪═════════════╡
│ 2026-04-15 │       8.134 │
│ 2026-04-16 │       5.814 │
│ 2026-04-14 │       4.822 │
│ 2026-04-12 │       4.656 │
│ 2026-04-17 │       4.501 │
│ 2026-04-10 │       4.017 │
│ 2026-04-18 │       4.016 │
│ 2026-04-11 │       2.614 │
│ 2026-04-13 │       2.436 │
│ 2026-04-09 │       2.303 │
╰────────────┴─────────────╯
```

### Get the usage data with the most used app on that day

```bash
~ ❯ sqlite3 hyprcapture.sqlite "
    WITH daily AS (
      SELECT
        date,
        class,
        title,
        SUM(duration) AS total_duration
      FROM usage
      GROUP BY date, class, title
    ),
    ranked AS (
      SELECT
        date,
        class,
        title,
        total_duration,
        ROW_NUMBER() OVER (
          PARTITION BY date
          ORDER BY total_duration DESC
        ) AS rn
      FROM daily
    ),
    totals AS (
      SELECT
        date,
        SUM(duration) AS day_duration
      FROM usage
      GROUP BY date
    )
    SELECT
      t.date,
      ROUND(t.day_duration / 3600e9, 3) AS total_hours,
      r.class || '-' || r.title AS top_app,
      ROUND(r.total_duration / 3600e9, 3) AS top_app_hours
    FROM ranked r
    JOIN totals t ON t.date = r.date
    WHERE r.rn = 1
    ORDER BY total_hours DESC;
    "
╭────────────┬─────────────┬────────────────────────────┬───────────────╮
│    date    │ total_hours │          top_app           │ top_app_hours │
╞════════════╪═════════════╪════════════════════════════╪═══════════════╡
│ 2026-04-15 │       8.134 │ nvim-mordith               │         4.522 │
│ 2026-04-16 │       5.814 │ nvim-mordith               │         3.685 │
│ 2026-04-14 │       4.822 │ nvim-mordith               │         1.279 │
│ 2026-04-12 │       4.656 │ nvim-mordith               │         3.884 │
│ 2026-04-17 │       4.501 │ nvim-mordith               │         3.635 │
│ 2026-04-18 │       4.079 │ nvim-mordith               │         1.784 │
│ 2026-04-10 │       4.017 │ nvim-mordith               │         2.096 │
│ 2026-04-11 │       2.614 │ nvim-mordith               │         1.835 │
│ 2026-04-13 │       2.436 │ nvim-adjustable_spray_wall │         0.436 │
│ 2026-04-09 │       2.303 │ nvim-backend               │         1.021 │
╰────────────┴─────────────┴────────────────────────────┴───────────────╯
```
