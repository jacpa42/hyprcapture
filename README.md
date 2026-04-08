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
    "class": "firefox",
    "title": "2 Hour Low Poly Ethereal Intelligent DnB | Jungle | Break Mix for HARD CODING - YouTube — Mozilla Firefox",
    "duration": 1250000000
  },
  {
    "class": "nvim",
    "title": "hyprcapture",
    "duration": 9250000000
  }
]
```

### Print out the table as json with second duration instead of nanosecond

```bash
~ ❯ sqlite3 -json hyprcapture.sqlite "SELECT class, title, duration / 1e9 AS duration FROM usage;" | jq
[
  {
    "class": "nvim",
    "title": "hyprcapture",
    "duration": 7.4
  },
  {
    "class": "firefox",
    "title": "ChatGPT — Mozilla Firefox",
    "duration": 5.85
  }
]
```
