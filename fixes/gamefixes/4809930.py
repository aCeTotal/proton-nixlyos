"""Game fix for Wardogs (Elytra Anti-Cheat)"""

import os

from protonfixes import util


def main() -> None:
    """Create dosdevices symlinks so Elytra's volume-GUID lookups resolve.

    The volume GUID's last byte is the drive letter's ASCII value
    (C = 0x43, W = 0x57). volume{...43} lets the service reach its cab
    file on C:, and W: + volume{...57} give the game dir a real volume
    mount so GetVolumeNameForVolumeMountPointW succeeds. The missing
    ntdll.RtlStringFromGUIDEx is handled by a wine patch, not here.
    """
    dosdevices = util.protonprefix() / 'dosdevices'
    gamedir = os.getcwd()
    links = {
        'volume{00000000-0000-0000-0000-000000000043}': '../drive_c',
        'w:': gamedir,
        'volume{00000000-0000-0000-0000-000000000057}': gamedir,
    }
    for name, target in links.items():
        path = dosdevices / name
        if path.is_symlink():
            path.unlink()
        if not path.exists():
            path.symlink_to(target)
