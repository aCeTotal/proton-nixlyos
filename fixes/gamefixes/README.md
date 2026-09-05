# Gamefixes

Per-game protonfixes modules, copied into `protonfixes/gamefixes-steam/`
in the final tarball. One file per game, named `<steam appid>.py`:

```python
"""Example: 12345.py"""
from protonfixes import util

def main():
    util.protontricks("vcrun2019")
```

See <https://github.com/Open-Wine-Components/umu-protonfixes> for the
available `util` helpers and existing fixes.
