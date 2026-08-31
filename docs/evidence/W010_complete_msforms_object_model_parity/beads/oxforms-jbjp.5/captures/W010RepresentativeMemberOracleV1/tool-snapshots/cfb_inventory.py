"""Strict, dependency-free inventory reader for MS-CFB compound files.

The reader is intentionally an inventory/extraction utility rather than a CFB
writer.  It accepts either a bare compound file or a larger byte slice (for
example, an MSForms ``.frx`` payload) containing a CFB signature.  All offsets
reported by the public inventory are relative to the supplied byte slice.

The implementation follows [MS-CFB] sector allocation rules and rejects
truncated, cyclic, overlong, overlapping, or otherwise out-of-bounds chains.
It does not attempt to repair malformed files: evidence generation must fail
closed rather than silently inventing a plausible interpretation.

Evidence-policy strictness: [MS-CFB] states a user-data chain has to be large
enough for its declared stream size.  This reader additionally requires the
minimal whole-sector chain and ENDOFCHAIN immediately after it.  The stricter
rule prevents unreported data from being hidden in surplus allocated sectors.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
import hashlib
from pathlib import Path
import struct
from types import MappingProxyType
from typing import Any, Mapping, Sequence


CFB_SIGNATURE = bytes.fromhex("D0 CF 11 E0 A1 B1 1A E1")

FREESECT = 0xFFFFFFFF
ENDOFCHAIN = 0xFFFFFFFE
FATSECT = 0xFFFFFFFD
DIFSECT = 0xFFFFFFFC
MAXREGSECT = 0xFFFFFFFA
NOSTREAM = 0xFFFFFFFF

_TWO_GIB = 0x80000000
_RANGE_LOCK_LAST_BYTE = 0x7FFFFFFF

_TYPE_NAMES = {1: "storage", 2: "stream", 5: "root"}


class CFBError(ValueError):
    """Raised when a byte slice is not a structurally valid CFB file."""


@dataclass(frozen=True)
class InventoryEntry:
    """One reachable, non-empty CFB directory entry."""

    path: str
    entry_type: str
    size: int
    sha256: str | None
    directory_id: int
    start_sector: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "type": self.entry_type,
            "size": self.size,
            "sha256": self.sha256,
            "directory_id": self.directory_id,
            "start_sector": self.start_sector,
        }


@dataclass(frozen=True)
class ByteRegion:
    """A hashed byte range in either the physical or mini-stream inventory."""

    classification: str
    offset: int
    length: int
    sha256: str
    owner: str | None = None
    sector_id: int | None = None
    mini_sector_id: int | None = None
    fat_value: int | None = None

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "classification": self.classification,
            "offset": self.offset,
            "length": self.length,
            "sha256": self.sha256,
        }
        if self.owner is not None:
            result["owner"] = self.owner
        if self.sector_id is not None:
            result["sector_id"] = self.sector_id
        if self.mini_sector_id is not None:
            result["mini_sector_id"] = self.mini_sector_id
        if self.fat_value is not None:
            result["fat_value"] = f"0x{self.fat_value:08X}"
        return result


@dataclass(frozen=True)
class CFBInventory:
    """Deterministic compound-file inventory plus extracted stream access."""

    signature_offset: int
    cfb_length: int
    major_version: int
    minor_version: int
    sector_size: int
    mini_sector_size: int
    sector_count: int
    entries: tuple[InventoryEntry, ...]
    physical_regions: tuple[ByteRegion, ...]
    mini_physical_regions: tuple[ByteRegion, ...]
    byte_regions: tuple[ByteRegion, ...]
    mini_regions: tuple[ByteRegion, ...]
    _streams: Mapping[str, bytes] = field(repr=False, compare=False)

    def to_dict(self) -> dict[str, Any]:
        """Return a JSON-serializable representation with stable ordering."""

        return {
            "format": "MS-CFB",
            "signature_offset": self.signature_offset,
            "cfb_length": self.cfb_length,
            "major_version": self.major_version,
            "minor_version": self.minor_version,
            "sector_size": self.sector_size,
            "mini_sector_size": self.mini_sector_size,
            "sector_count": self.sector_count,
            "entries": [entry.to_dict() for entry in self.entries],
            "physical_regions": [
                region.to_dict() for region in self.physical_regions
            ],
            "mini_physical_regions": [
                region.to_dict() for region in self.mini_physical_regions
            ],
            "byte_regions": [region.to_dict() for region in self.byte_regions],
            "mini_regions": [region.to_dict() for region in self.mini_regions],
        }

    @property
    def streams(self) -> Mapping[str, bytes]:
        """Extracted stream bytes keyed by canonical absolute storage path."""

        return self._streams

    def read_stream(self, path: str) -> bytes:
        """Return an extracted stream, raising ``KeyError`` for non-streams."""

        return self._streams[path]


@dataclass(frozen=True)
class _Header:
    minor_version: int
    major_version: int
    sector_size: int
    mini_sector_size: int
    directory_sector_count: int
    fat_sector_count: int
    first_directory_sector: int
    mini_stream_cutoff: int
    first_minifat_sector: int
    minifat_sector_count: int
    first_difat_sector: int
    difat_sector_count: int
    header_difat: tuple[int, ...]


@dataclass(frozen=True)
class _DirectoryEntry:
    directory_id: int
    name: str
    object_type: int
    color: int
    left: int
    right: int
    child: int
    clsid: bytes
    state_bits: int
    creation_time: int
    modified_time: int
    start_sector: int
    size: int


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def _u64(data: bytes, offset: int) -> int:
    return struct.unpack_from("<Q", data, offset)[0]


def _simple_upper_utf16_unit(unit: int) -> int:
    """Apply Unicode simple uppercase to one UTF-16 code unit.

    Python's ``str.upper`` implements full uppercase and can expand one code
    point to several.  MS-CFB requires the simple variant and explicitly leaves
    surrogate code units unchanged.  A multi-character full mapping therefore
    has no usable one-unit mapping here and remains unchanged.
    """

    if 0xD800 <= unit <= 0xDFFF:
        return unit
    # These Greek characters have a one-code-point simple uppercase mapping
    # even though Python's full uppercase mapping expands them with iota.
    if 0x1F80 <= unit <= 0x1F87:
        return unit + 8
    if 0x1F90 <= unit <= 0x1F97:
        return unit + 8
    if 0x1FA0 <= unit <= 0x1FA7:
        return unit + 8
    greek_iota_forms = {0x1FB3: 0x1FBC, 0x1FC3: 0x1FCC, 0x1FF3: 0x1FFC}
    if unit in greek_iota_forms:
        return greek_iota_forms[unit]
    upper = chr(unit).upper()
    if len(upper) == 1 and ord(upper) <= 0xFFFF:
        return ord(upper)
    return unit


def _cfb_name_key(name: str) -> tuple[int, tuple[int, ...]]:
    encoded = name.encode("utf-16-le")
    units = struct.unpack(f"<{len(encoded) // 2}H", encoded) if encoded else ()
    # The terminating null is included in Directory Entry Name Length for the
    # first comparison but is irrelevant to the subsequent code-unit ordering.
    return len(encoded) + 2, tuple(_simple_upper_utf16_unit(unit) for unit in units)


def _plausible_header(data: bytes, offset: int) -> bool:
    if offset < 0 or offset + 512 > len(data):
        return False
    if data[offset : offset + 8] != CFB_SIGNATURE:
        return False
    major = _u16(data, offset + 26)
    shift = _u16(data, offset + 30)
    return (
        _u16(data, offset + 28) == 0xFFFE
        and ((major == 3 and shift == 9) or (major == 4 and shift == 12))
        and _u16(data, offset + 32) == 6
    )


def find_cfb_offsets(data: bytes | bytearray | memoryview) -> tuple[int, ...]:
    """Return all structurally plausible CFB signature offsets in ``data``."""

    raw = bytes(data)
    offsets: list[int] = []
    cursor = 0
    while True:
        offset = raw.find(CFB_SIGNATURE, cursor)
        if offset < 0:
            break
        if _plausible_header(raw, offset):
            offsets.append(offset)
        cursor = offset + 1
    return tuple(offsets)


def discover_cfb_offset(data: bytes | bytearray | memoryview) -> int:
    """Discover one CFB offset, rejecting absent or ambiguous containers."""

    offsets = find_cfb_offsets(data)
    if not offsets:
        raise CFBError("no plausible CFB signature was found")
    if len(offsets) != 1:
        joined = ", ".join(str(offset) for offset in offsets)
        raise CFBError(
            f"multiple plausible CFB signatures were found at {joined}; "
            "supply signature_offset explicitly"
        )
    return offsets[0]


def parse_cfb(
    data: bytes | bytearray | memoryview,
    signature_offset: int | None = None,
) -> CFBInventory:
    """Parse and inventory a CFB file embedded in the supplied byte slice."""

    raw = bytes(data)
    if signature_offset is None:
        signature_offset = discover_cfb_offset(raw)
    elif isinstance(signature_offset, bool) or not isinstance(signature_offset, int):
        raise TypeError("signature_offset must be an integer or None")
    if signature_offset < 0:
        raise CFBError("signature_offset cannot be negative")
    if signature_offset + 8 > len(raw):
        raise CFBError("signature_offset is outside the supplied byte slice")
    if raw[signature_offset : signature_offset + 8] != CFB_SIGNATURE:
        raise CFBError(f"CFB signature is absent at offset {signature_offset}")

    parser = _Parser(raw, signature_offset)
    return parser.parse()


def parse_cfb_file(
    path: str | Path,
    signature_offset: int | None = None,
) -> CFBInventory:
    """Read, parse, and inventory a file from disk."""

    return parse_cfb(Path(path).read_bytes(), signature_offset=signature_offset)


def inventory_cfb(
    data: bytes | bytearray | memoryview,
    signature_offset: int | None = None,
) -> dict[str, Any]:
    """Convenience wrapper returning only the JSON-serializable inventory."""

    return parse_cfb(data, signature_offset=signature_offset).to_dict()


def inventory_cfb_file(
    path: str | Path,
    signature_offset: int | None = None,
) -> dict[str, Any]:
    """File-based convenience wrapper returning a serializable inventory."""

    return parse_cfb_file(path, signature_offset=signature_offset).to_dict()


class _Parser:
    def __init__(self, data: bytes, signature_offset: int) -> None:
        self.data = data
        self.base = signature_offset
        self.header = self._read_header()
        available = len(data) - self.base
        complete_units = available // self.header.sector_size
        if complete_units < 2:
            raise CFBError(
                "CFB byte slice does not contain a header sector and one data sector"
            )
        self.sector_count = complete_units - 1
        self.cfb_end = self.base + complete_units * self.header.sector_size
        if self.header.sector_size > 512:
            header_padding = data[self.base + 512 : self.base + self.header.sector_size]
            if any(header_padding):
                raise CFBError("version 4 CFB header-sector padding must be zero")
        self.claimed_sectors: dict[int, str] = {}
        self.claimed_mini_sectors: dict[int, str] = {}
        self.fat: tuple[int, ...] = ()
        self.minifat: tuple[int, ...] = ()

    def _read_header(self) -> _Header:
        if self.base + 512 > len(self.data):
            raise CFBError("truncated CFB header")
        header = self.data[self.base : self.base + 512]
        if header[:8] != CFB_SIGNATURE:
            raise CFBError("invalid CFB signature")
        if header[8:24] != bytes(16):
            raise CFBError("CFB header CLSID must be zero")
        minor = _u16(header, 24)
        major = _u16(header, 26)
        if minor != 0x003E:
            raise CFBError(
                f"CFB minor version must be 0x003E, found 0x{minor:04X}"
            )
        if major not in (3, 4):
            raise CFBError(f"unsupported CFB major version {major}")
        if _u16(header, 28) != 0xFFFE:
            raise CFBError("CFB byte order must be little-endian 0xFFFE")
        sector_shift = _u16(header, 30)
        required_shift = 9 if major == 3 else 12
        if sector_shift != required_shift:
            raise CFBError(
                f"CFB version {major} requires sector shift {required_shift}, "
                f"found {sector_shift}"
            )
        mini_shift = _u16(header, 32)
        if mini_shift != 6:
            raise CFBError(f"unsupported CFB mini-sector shift {mini_shift}")
        if header[34:40] != bytes(6):
            raise CFBError("CFB reserved header bytes must be zero")

        directory_sector_count = _u32(header, 40)
        if major == 3 and directory_sector_count != 0:
            raise CFBError("version 3 CFB directory-sector count must be zero")
        mini_stream_cutoff = _u32(header, 56)
        if mini_stream_cutoff != 0x1000:
            raise CFBError(
                f"CFB mini-stream cutoff must be 4096, found {mini_stream_cutoff}"
            )
        return _Header(
            minor_version=minor,
            major_version=major,
            sector_size=1 << sector_shift,
            mini_sector_size=1 << mini_shift,
            directory_sector_count=directory_sector_count,
            fat_sector_count=_u32(header, 44),
            first_directory_sector=_u32(header, 48),
            mini_stream_cutoff=mini_stream_cutoff,
            first_minifat_sector=_u32(header, 60),
            minifat_sector_count=_u32(header, 64),
            first_difat_sector=_u32(header, 68),
            difat_sector_count=_u32(header, 72),
            header_difat=tuple(struct.unpack_from("<109I", header, 76)),
        )

    def _sector_offset(self, sector_id: int) -> int:
        self._require_regular_sector(sector_id, "sector reference")
        return self.base + (sector_id + 1) * self.header.sector_size

    def _sector(self, sector_id: int, label: str) -> bytes:
        self._require_regular_sector(sector_id, label)
        offset = self.base + (sector_id + 1) * self.header.sector_size
        end = offset + self.header.sector_size
        if end > self.cfb_end:
            raise CFBError(f"{label} sector {sector_id} overruns the CFB boundary")
        return self.data[offset:end]

    def _require_regular_sector(self, sector_id: int, label: str) -> None:
        if sector_id > MAXREGSECT:
            raise CFBError(f"{label} uses reserved sector value 0x{sector_id:08X}")
        if sector_id >= self.sector_count:
            raise CFBError(
                f"{label} sector {sector_id} is outside 0..{self.sector_count - 1}"
            )

    def _claim_sector(self, sector_id: int, owner: str) -> None:
        previous = self.claimed_sectors.get(sector_id)
        if previous is not None:
            raise CFBError(
                f"sector {sector_id} is multiply allocated to {previous!r} "
                f"and {owner!r}"
            )
        self.claimed_sectors[sector_id] = owner

    def _claim_mini_sector(self, sector_id: int, owner: str) -> None:
        previous = self.claimed_mini_sectors.get(sector_id)
        if previous is not None:
            raise CFBError(
                f"mini-sector {sector_id} is multiply allocated to "
                f"{previous!r} and {owner!r}"
            )
        self.claimed_mini_sectors[sector_id] = owner

    def _read_difat(self) -> tuple[tuple[int, ...], tuple[int, ...]]:
        count = self.header.difat_sector_count
        current = self.header.first_difat_sector
        difat_sector_ids: list[int] = []
        difat_slots = list(self.header.header_difat)
        seen: set[int] = set()

        if count == 0:
            if current != ENDOFCHAIN:
                raise CFBError(
                    "zero DIFAT-sector count requires ENDOFCHAIN as first DIFAT sector"
                )
        else:
            for index in range(count):
                self._require_regular_sector(current, "DIFAT chain")
                if current in seen:
                    raise CFBError(f"DIFAT chain cycle at sector {current}")
                seen.add(current)
                difat_sector_ids.append(current)
                values = struct.unpack(
                    f"<{self.header.sector_size // 4}I",
                    self._sector(current, "DIFAT chain"),
                )
                difat_slots.extend(values[:-1])
                next_sector = values[-1]
                if index + 1 == count:
                    if next_sector != ENDOFCHAIN:
                        raise CFBError(
                            "DIFAT chain overruns its declared sector count"
                        )
                else:
                    if next_sector == ENDOFCHAIN:
                        raise CFBError(
                            "DIFAT chain ends before its declared sector count"
                        )
                    current = next_sector

        first_free: int | None = None
        fat_sector_ids: list[int] = []
        for slot_index, sector_id in enumerate(difat_slots):
            if sector_id == FREESECT:
                if first_free is None:
                    first_free = slot_index
                continue
            if first_free is not None:
                raise CFBError(
                    "DIFAT contains a non-free FAT sector after its first FREESECT slot"
                )
            self._require_regular_sector(sector_id, "DIFAT FAT-sector entry")
            fat_sector_ids.append(sector_id)

        if len(fat_sector_ids) != self.header.fat_sector_count:
            raise CFBError(
                "DIFAT enumerates "
                f"{len(fat_sector_ids)} FAT sectors, header declares "
                f"{self.header.fat_sector_count}"
            )
        if not fat_sector_ids:
            raise CFBError("CFB file has no FAT sectors")
        if len(set(fat_sector_ids)) != len(fat_sector_ids):
            raise CFBError("DIFAT enumerates a FAT sector more than once")
        if set(fat_sector_ids).intersection(difat_sector_ids):
            raise CFBError("a sector is listed as both FAT and DIFAT")
        return tuple(fat_sector_ids), tuple(difat_sector_ids)

    def _read_fat(self, fat_sector_ids: Sequence[int]) -> tuple[int, ...]:
        entries: list[int] = []
        count = self.header.sector_size // 4
        for sector_id in fat_sector_ids:
            entries.extend(
                struct.unpack(f"<{count}I", self._sector(sector_id, "FAT"))
            )
        return tuple(entries)

    def _establish_logical_extent(self) -> None:
        allocated = [
            sector_id
            for sector_id, marker in enumerate(self.fat)
            if marker != FREESECT
        ]
        if not allocated:
            raise CFBError("FAT does not allocate any sectors")
        logical_sector_count = allocated[-1] + 1
        if logical_sector_count > self.sector_count:
            raise CFBError(
                f"FAT allocates through sector {logical_sector_count - 1}, but "
                f"only {self.sector_count} physical sectors are available"
            )
        self.sector_count = logical_sector_count
        self.cfb_end = self.base + (
            logical_sector_count + 1
        ) * self.header.sector_size

    def _validate_allocation_markers(
        self,
        fat_sector_ids: Sequence[int],
        difat_sector_ids: Sequence[int],
    ) -> None:
        for sector_id in fat_sector_ids:
            if sector_id >= len(self.fat):
                raise CFBError(
                    f"FAT sector {sector_id} cannot be addressed by the "
                    f"{len(self.fat)}-entry FAT"
                )
            if self.fat[sector_id] != FATSECT:
                raise CFBError(
                    f"FAT sector {sector_id} has allocation marker "
                    f"0x{self.fat[sector_id]:08X}, expected FATSECT"
                )
            self._claim_sector(sector_id, "FAT")
        for sector_id in difat_sector_ids:
            if sector_id >= len(self.fat):
                raise CFBError(
                    f"DIFAT sector {sector_id} cannot be addressed by the "
                    f"{len(self.fat)}-entry FAT"
                )
            if self.fat[sector_id] != DIFSECT:
                raise CFBError(
                    f"DIFAT sector {sector_id} has allocation marker "
                    f"0x{self.fat[sector_id]:08X}, expected DIFSECT"
                )
            self._claim_sector(sector_id, "DIFAT")
        fat_set = set(fat_sector_ids)
        difat_set = set(difat_sector_ids)
        for sector_id, marker in enumerate(self.fat[: self.sector_count]):
            if marker == FATSECT and sector_id not in fat_set:
                raise CFBError(
                    f"sector {sector_id} has a FATSECT marker but is absent from DIFAT"
                )
            if marker == DIFSECT and sector_id not in difat_set:
                raise CFBError(
                    f"sector {sector_id} has a DIFSECT marker but is absent from "
                    "the DIFAT chain"
                )

    def _claim_range_lock_sector_if_required(self) -> None:
        cfb_length = self.cfb_end - self.base
        if cfb_length <= _TWO_GIB:
            return
        if self.header.major_version != 4:
            raise CFBError("a version 3 CFB file cannot exceed 2 GiB")
        range_lock_sector = (
            _RANGE_LOCK_LAST_BYTE // self.header.sector_size
        ) - 1
        self._require_regular_sector(range_lock_sector, "range-lock sector")
        if self.fat[range_lock_sector] != ENDOFCHAIN:
            raise CFBError(
                f"range-lock sector {range_lock_sector} must be marked "
                "ENDOFCHAIN in a CFB file larger than 2 GiB"
            )
        self._claim_sector(range_lock_sector, "range lock")

    def _follow_fat_chain(
        self,
        start_sector: int,
        label: str,
        expected_count: int | None = None,
    ) -> tuple[int, ...]:
        if expected_count is not None and expected_count < 0:
            raise AssertionError("negative expected chain length")
        if expected_count == 0:
            if start_sector != ENDOFCHAIN:
                raise CFBError(
                    f"{label} must use ENDOFCHAIN for an empty chain"
                )
            return ()
        if start_sector in (ENDOFCHAIN, FREESECT):
            raise CFBError(f"{label} is missing its first sector")

        result: list[int] = []
        seen: set[int] = set()
        current = start_sector
        while True:
            self._require_regular_sector(current, label)
            if current in seen:
                raise CFBError(f"{label} cycle at sector {current}")
            seen.add(current)
            result.append(current)
            next_sector = self.fat[current]
            if expected_count is not None and len(result) == expected_count:
                if next_sector != ENDOFCHAIN:
                    raise CFBError(
                        f"{label} overruns its expected {expected_count}-sector length"
                    )
                break
            if next_sector == ENDOFCHAIN:
                break
            if next_sector > MAXREGSECT:
                raise CFBError(
                    f"{label} encounters reserved FAT value 0x{next_sector:08X}"
                )
            current = next_sector

        if expected_count is not None and len(result) != expected_count:
            raise CFBError(
                f"{label} has {len(result)} sectors, expected {expected_count}"
            )
        return tuple(result)

    def _read_regular_stream(
        self,
        start_sector: int,
        size: int,
        label: str,
        owner: str,
    ) -> tuple[bytes, tuple[int, ...]]:
        expected = (size + self.header.sector_size - 1) // self.header.sector_size
        chain = self._follow_fat_chain(start_sector, label, expected)
        for sector_id in chain:
            self._claim_sector(sector_id, owner)
        payload = b"".join(self._sector(sector_id, label) for sector_id in chain)
        return payload[:size], chain

    def _read_minifat(self) -> tuple[int, ...]:
        count = self.header.minifat_sector_count
        chain = self._follow_fat_chain(
            self.header.first_minifat_sector,
            "miniFAT chain",
            count,
        )
        for sector_id in chain:
            self._claim_sector(sector_id, "miniFAT")
        entries: list[int] = []
        per_sector = self.header.sector_size // 4
        for sector_id in chain:
            entries.extend(
                struct.unpack(
                    f"<{per_sector}I", self._sector(sector_id, "miniFAT")
                )
            )
        return tuple(entries)

    def _follow_mini_chain(
        self,
        start_sector: int,
        expected_count: int,
        label: str,
        mini_sector_capacity: int,
    ) -> tuple[int, ...]:
        if expected_count == 0:
            if start_sector != ENDOFCHAIN:
                raise CFBError(
                    f"{label} must use ENDOFCHAIN for an empty stream"
                )
            return ()
        if start_sector in (ENDOFCHAIN, FREESECT):
            raise CFBError(f"{label} is missing its first mini-sector")
        result: list[int] = []
        seen: set[int] = set()
        current = start_sector
        while True:
            if current > MAXREGSECT:
                raise CFBError(
                    f"{label} uses reserved mini-sector value 0x{current:08X}"
                )
            if current >= len(self.minifat):
                raise CFBError(
                    f"{label} mini-sector {current} exceeds miniFAT bounds"
                )
            if current >= mini_sector_capacity:
                raise CFBError(
                    f"{label} mini-sector {current} exceeds root mini-stream capacity "
                    f"{mini_sector_capacity}"
                )
            if current in seen:
                raise CFBError(f"{label} cycle at mini-sector {current}")
            seen.add(current)
            result.append(current)
            next_sector = self.minifat[current]
            if len(result) == expected_count:
                if next_sector != ENDOFCHAIN:
                    raise CFBError(
                        f"{label} overruns its expected "
                        f"{expected_count}-mini-sector length"
                    )
                break
            if next_sector == ENDOFCHAIN:
                raise CFBError(
                    f"{label} has {len(result)} mini-sectors, expected {expected_count}"
                )
            if next_sector > MAXREGSECT:
                raise CFBError(
                    f"{label} encounters reserved miniFAT value 0x{next_sector:08X}"
                )
            current = next_sector
        return tuple(result)

    def _read_directory(self) -> tuple[tuple[_DirectoryEntry, ...], tuple[int, ...]]:
        expected = (
            self.header.directory_sector_count
            if self.header.major_version == 4
            else None
        )
        if expected == 0:
            raise CFBError("CFB directory chain cannot be empty")
        chain = self._follow_fat_chain(
            self.header.first_directory_sector,
            "directory chain",
            expected,
        )
        if not chain:
            raise CFBError("CFB directory chain cannot be empty")
        for sector_id in chain:
            self._claim_sector(sector_id, "directory")
        payload = b"".join(
            self._sector(sector_id, "directory chain") for sector_id in chain
        )
        result: list[_DirectoryEntry] = []
        for directory_id, offset in enumerate(range(0, len(payload), 128)):
            entry = payload[offset : offset + 128]
            object_type = entry[66]
            if object_type == 0:
                expected_empty = bytearray(128)
                struct.pack_into(
                    "<III",
                    expected_empty,
                    68,
                    NOSTREAM,
                    NOSTREAM,
                    NOSTREAM,
                )
                if entry != bytes(expected_empty):
                    raise CFBError(
                        f"empty directory entry {directory_id} is not zero-filled "
                        "with NOSTREAM links"
                    )
                name = ""
            else:
                if object_type not in _TYPE_NAMES:
                    raise CFBError(
                        f"directory entry {directory_id} has invalid type {object_type}"
                    )
                name_length = _u16(entry, 64)
                if name_length < 2 or name_length > 64 or name_length % 2:
                    raise CFBError(
                        f"directory entry {directory_id} has invalid name length "
                        f"{name_length}"
                    )
                name_bytes = entry[: name_length - 2]
                if entry[name_length - 2 : name_length] != b"\x00\x00":
                    raise CFBError(
                        f"directory entry {directory_id} name is not null-terminated"
                    )
                try:
                    name = name_bytes.decode("utf-16-le")
                except UnicodeDecodeError as exc:
                    raise CFBError(
                        f"directory entry {directory_id} name is not valid UTF-16LE"
                    ) from exc
                if not name or "\x00" in name:
                    raise CFBError(
                        f"directory entry {directory_id} has an invalid "
                        "empty/embedded-null name"
                    )
                prohibited = sorted(set(name).intersection("/\\:!"))
                if prohibited:
                    raise CFBError(
                        f"directory entry {directory_id} name contains prohibited "
                        f"character(s): {''.join(prohibited)!r}"
                    )
            color = entry[67]
            if object_type != 0 and color not in (0, 1):
                raise CFBError(
                    f"directory entry {directory_id} has invalid color {color}"
                )
            left = _u32(entry, 68)
            right = _u32(entry, 72)
            child = _u32(entry, 76)
            clsid = entry[80:96]
            state_bits = _u32(entry, 96)
            creation_time = _u64(entry, 100)
            modified_time = _u64(entry, 108)
            start_sector = _u32(entry, 116)
            size = _u64(entry, 120)
            if self.header.major_version == 3 and object_type in (2, 5):
                if size > 0x80000000:
                    raise CFBError(
                        f"version 3 directory entry {directory_id} stream size "
                        "exceeds 2 GiB"
                    )
            if object_type == 2:
                if clsid != bytes(16):
                    raise CFBError(
                        f"stream directory entry {directory_id} has a nonzero CLSID"
                    )
                if child != NOSTREAM:
                    raise CFBError(
                        f"stream directory entry {directory_id} has a child link"
                    )
                if creation_time or modified_time:
                    raise CFBError(
                        f"stream directory entry {directory_id} has a nonzero "
                        "timestamp"
                    )
            elif object_type == 1:
                if start_sector != 0:
                    raise CFBError(
                        f"storage directory entry {directory_id} has nonzero "
                        "starting sector"
                    )
                if size != 0:
                    raise CFBError(
                        f"storage directory entry {directory_id} has nonzero size"
                    )
            elif object_type == 5 and creation_time != 0:
                raise CFBError("root directory creation time must be zero")
            result.append(
                _DirectoryEntry(
                    directory_id=directory_id,
                    name=name,
                    object_type=object_type,
                    color=color,
                    left=left,
                    right=right,
                    child=child,
                    clsid=clsid,
                    state_bits=state_bits,
                    creation_time=creation_time,
                    modified_time=modified_time,
                    start_sector=start_sector,
                    size=size,
                )
            )
        return tuple(result), chain

    @staticmethod
    def _entry_path(parent_path: str, name: str) -> str:
        return f"/{name}" if parent_path == "/" else f"{parent_path}/{name}"

    def _directory_paths(
        self, entries: Sequence[_DirectoryEntry]
    ) -> dict[int, str]:
        if not entries or entries[0].object_type != 5:
            raise CFBError("directory entry zero must be the root storage")
        if any(entry.object_type == 5 for entry in entries[1:]):
            raise CFBError("CFB directory contains more than one root storage")
        root = entries[0]
        if root.name != "Root Entry":
            raise CFBError("root directory entry must be named 'Root Entry'")
        if root.left != NOSTREAM or root.right != NOSTREAM:
            raise CFBError("root directory entry cannot have sibling links")

        paths = {0: "/"}
        assigned = {0}
        pending = deque([("/", root.child)])
        while pending:
            parent_path, tree_root = pending.popleft()
            if tree_root == NOSTREAM:
                continue
            if tree_root >= len(entries):
                raise CFBError(
                    f"directory tree under {parent_path!r} references entry "
                    f"{tree_root} outside 0..{len(entries) - 1}"
                )
            if entries[tree_root].color != 1:
                raise CFBError(
                    f"directory sibling-tree root {tree_root} under "
                    f"{parent_path!r} must be black"
                )
            ordered: list[int] = []
            visiting: set[int] = set()
            completed: set[int] = set()
            stack: list[tuple[int, int]] = [(tree_root, 0)]
            while stack:
                directory_id, state = stack.pop()
                if directory_id == NOSTREAM:
                    continue
                if directory_id >= len(entries):
                    raise CFBError(
                        f"directory tree under {parent_path!r} references entry "
                        f"{directory_id} outside 0..{len(entries) - 1}"
                    )
                entry = entries[directory_id]
                if entry.object_type == 0:
                    raise CFBError(
                        f"directory tree under {parent_path!r} references empty entry "
                        f"{directory_id}"
                    )
                if directory_id in assigned:
                    raise CFBError(
                        f"directory entry {directory_id} is referenced by more "
                        "than one tree"
                    )
                if state == 0:
                    if directory_id in visiting:
                        raise CFBError(
                            f"directory sibling-tree cycle at entry {directory_id}"
                        )
                    if directory_id in completed:
                        raise CFBError(
                            f"directory entry {directory_id} is referenced more "
                            "than once"
                        )
                    visiting.add(directory_id)
                    stack.append((directory_id, 1))
                    if entry.left != NOSTREAM:
                        stack.append((entry.left, 0))
                elif state == 1:
                    ordered.append(directory_id)
                    stack.append((directory_id, 2))
                    if entry.right != NOSTREAM:
                        stack.append((entry.right, 0))
                else:
                    visiting.remove(directory_id)
                    completed.add(directory_id)

            previous_key: tuple[int, tuple[int, ...]] | None = None
            previous_name: str | None = None
            for directory_id in ordered:
                entry = entries[directory_id]
                key = _cfb_name_key(entry.name)
                if previous_key is not None and key <= previous_key:
                    relationship = "duplicate" if key == previous_key else "misordered"
                    raise CFBError(
                        f"storage {parent_path!r} has {relationship} sibling "
                        f"names {previous_name!r} and {entry.name!r}"
                    )
                previous_key = key
                previous_name = entry.name
                path = self._entry_path(parent_path, entry.name)
                paths[directory_id] = path
                assigned.add(directory_id)
                if entry.object_type in (1, 5):
                    pending.append((path, entry.child))
                elif entry.child != NOSTREAM:
                    raise CFBError(f"stream {path!r} has an invalid child link")
            for directory_id in completed:
                entry = entries[directory_id]
                if entry.color != 0:
                    continue
                for child_id in (entry.left, entry.right):
                    if child_id != NOSTREAM and entries[child_id].color == 0:
                        raise CFBError(
                            f"directory sibling tree has consecutive red entries "
                            f"{directory_id} and {child_id}"
                        )

        active = {
            entry.directory_id for entry in entries if entry.object_type != 0
        }
        unreachable = sorted(active - assigned)
        if unreachable:
            raise CFBError(
                "non-empty directory entries are unreachable from root: "
                + ", ".join(str(value) for value in unreachable)
            )
        return paths

    def _mini_sector_absolute_offset(
        self, mini_sector_id: int, root_chain: Sequence[int]
    ) -> int:
        logical_offset = mini_sector_id * self.header.mini_sector_size
        chain_index, within_sector = divmod(logical_offset, self.header.sector_size)
        if chain_index >= len(root_chain):
            raise CFBError(
                f"mini-sector {mini_sector_id} does not map into the root "
                "mini-stream chain"
            )
        return self._sector_offset(root_chain[chain_index]) + within_sector

    def _inventory_regions(
        self,
        root_data: bytes,
        root_chain: Sequence[int],
    ) -> tuple[tuple[ByteRegion, ...], tuple[ByteRegion, ...]]:
        byte_regions: list[ByteRegion] = []
        if self.base:
            prefix = self.data[: self.base]
            byte_regions.append(
                ByteRegion(
                    classification="prefix_before_cfb",
                    offset=0,
                    length=len(prefix),
                    sha256=_sha256(prefix),
                )
            )
        for sector_id in range(self.sector_count):
            if sector_id in self.claimed_sectors:
                continue
            sector = self._sector(sector_id, "unclaimed-sector inventory")
            fat_value = self.fat[sector_id]
            if fat_value != FREESECT:
                raise CFBError(
                    f"sector {sector_id} is allocated by FAT value "
                    f"0x{fat_value:08X} but has no reachable owner"
                )
            byte_regions.append(
                ByteRegion(
                    classification="unallocated_free_sector",
                    offset=self._sector_offset(sector_id),
                    length=self.header.sector_size,
                    sha256=_sha256(sector),
                    sector_id=sector_id,
                    fat_value=fat_value,
                )
            )
        if self.cfb_end < len(self.data):
            trailing = self.data[self.cfb_end :]
            byte_regions.append(
                ByteRegion(
                    classification="trailing_after_cfb_sector_boundary",
                    offset=self.cfb_end,
                    length=len(trailing),
                    sha256=_sha256(trailing),
                )
            )

        mini_regions: list[ByteRegion] = []
        mini_capacity = len(root_data) // self.header.mini_sector_size
        for mini_sector_id in range(mini_capacity):
            if mini_sector_id in self.claimed_mini_sectors:
                continue
            start = mini_sector_id * self.header.mini_sector_size
            payload = root_data[start : start + self.header.mini_sector_size]
            fat_value = (
                self.minifat[mini_sector_id]
                if mini_sector_id < len(self.minifat)
                else FREESECT
            )
            if fat_value != FREESECT:
                raise CFBError(
                    f"mini-sector {mini_sector_id} is allocated by miniFAT "
                    f"value 0x{fat_value:08X} but has no reachable owner"
                )
            mini_regions.append(
                ByteRegion(
                    classification="unallocated_free_mini_sector",
                    offset=self._mini_sector_absolute_offset(
                        mini_sector_id, root_chain
                    ),
                    length=self.header.mini_sector_size,
                    sha256=_sha256(payload),
                    mini_sector_id=mini_sector_id,
                    fat_value=fat_value,
                )
            )
        return (
            tuple(sorted(byte_regions, key=lambda region: region.offset)),
            tuple(sorted(mini_regions, key=lambda region: region.offset)),
        )

    def _physical_inventory(
        self,
        root_data: bytes,
        root_chain: Sequence[int],
    ) -> tuple[tuple[ByteRegion, ...], tuple[ByteRegion, ...]]:
        """Hash a complete physical partition plus the mini-stream overlay.

        Stream hashes alone omit sector slack, and a residual-only inventory
        omits allocated metadata sectors altogether.  The physical partition
        therefore covers every supplied input byte exactly once: outer prefix,
        header sector, each logical CFB data sector, and any outer suffix.  The
        mini-stream inventory is a second, explicitly overlapping logical view
        that hashes every allocated or free mini-sector in full so stream-tail
        bytes cannot disappear from the evidence model.
        """

        physical: list[ByteRegion] = []
        if self.base:
            payload = self.data[: self.base]
            physical.append(
                ByteRegion(
                    classification="prefix_before_cfb",
                    offset=0,
                    length=len(payload),
                    sha256=_sha256(payload),
                    owner="outer_container",
                )
            )

        header = self.data[self.base : self.base + self.header.sector_size]
        if len(header) != self.header.sector_size:
            raise CFBError("CFB header sector is truncated during physical inventory")
        physical.append(
            ByteRegion(
                classification="cfb_header_sector",
                offset=self.base,
                length=len(header),
                sha256=_sha256(header),
                owner="cfb_header",
            )
        )

        for sector_id in range(self.sector_count):
            payload = self._sector(sector_id, "physical-sector inventory")
            owner = self.claimed_sectors.get(sector_id)
            fat_value = self.fat[sector_id]
            if owner is None:
                if fat_value != FREESECT:
                    raise CFBError(
                        f"sector {sector_id} is allocated by FAT value "
                        f"0x{fat_value:08X} but has no reachable owner"
                    )
                classification = "unallocated_free_sector"
            else:
                classification = "allocated_cfb_sector"
            physical.append(
                ByteRegion(
                    classification=classification,
                    offset=self._sector_offset(sector_id),
                    length=self.header.sector_size,
                    sha256=_sha256(payload),
                    owner=owner,
                    sector_id=sector_id,
                    fat_value=fat_value,
                )
            )

        if self.cfb_end < len(self.data):
            payload = self.data[self.cfb_end :]
            physical.append(
                ByteRegion(
                    classification="trailing_after_cfb_sector_boundary",
                    offset=self.cfb_end,
                    length=len(payload),
                    sha256=_sha256(payload),
                    owner="outer_container",
                )
            )

        cursor = 0
        for region in physical:
            if region.length <= 0 or region.offset != cursor:
                raise CFBError(
                    "physical-region inventory is not a positive contiguous partition"
                )
            cursor += region.length
        if cursor != len(self.data):
            raise CFBError(
                f"physical-region inventory covers {cursor} of {len(self.data)} bytes"
            )

        mini_physical: list[ByteRegion] = []
        mini_capacity = len(root_data) // self.header.mini_sector_size
        for mini_sector_id in range(mini_capacity):
            start = mini_sector_id * self.header.mini_sector_size
            payload = root_data[start : start + self.header.mini_sector_size]
            if len(payload) != self.header.mini_sector_size:
                raise CFBError(
                    f"mini-sector {mini_sector_id} is truncated during inventory"
                )
            owner = self.claimed_mini_sectors.get(mini_sector_id)
            fat_value = self.minifat[mini_sector_id]
            if owner is None:
                if fat_value != FREESECT:
                    raise CFBError(
                        f"mini-sector {mini_sector_id} is allocated by miniFAT "
                        f"value 0x{fat_value:08X} but has no reachable owner"
                    )
                classification = "unallocated_free_mini_sector"
            else:
                classification = "allocated_mini_sector"
            mini_physical.append(
                ByteRegion(
                    classification=classification,
                    offset=self._mini_sector_absolute_offset(
                        mini_sector_id, root_chain
                    ),
                    length=self.header.mini_sector_size,
                    sha256=_sha256(payload),
                    owner=owner,
                    mini_sector_id=mini_sector_id,
                    fat_value=fat_value,
                )
            )
        return tuple(physical), tuple(mini_physical)

    def parse(self) -> CFBInventory:
        fat_sector_ids, difat_sector_ids = self._read_difat()
        self.fat = self._read_fat(fat_sector_ids)
        self._establish_logical_extent()
        self._validate_allocation_markers(fat_sector_ids, difat_sector_ids)
        self._claim_range_lock_sector_if_required()
        self.minifat = self._read_minifat()
        directory_entries, _ = self._read_directory()
        paths = self._directory_paths(directory_entries)
        root = directory_entries[0]

        root_data, root_chain = self._read_regular_stream(
            root.start_sector,
            root.size,
            "root mini-stream",
            "root mini-stream",
        )
        if len(root_data) % self.header.mini_sector_size:
            raise CFBError(
                "root mini-stream size is not a whole number of mini-sectors"
            )
        mini_capacity = len(root_data) // self.header.mini_sector_size
        if mini_capacity > len(self.minifat):
            raise CFBError(
                f"root mini-stream has {mini_capacity} mini-sectors but miniFAT "
                f"has only {len(self.minifat)} entries"
            )
        for mini_sector_id, marker in enumerate(
            self.minifat[mini_capacity:], start=mini_capacity
        ):
            if marker != FREESECT:
                raise CFBError(
                    f"miniFAT entry {mini_sector_id} is allocated beyond the "
                    f"root mini-stream capacity {mini_capacity}"
                )

        extracted: dict[str, bytes] = {}
        inventory_entries: list[InventoryEntry] = [
            InventoryEntry(
                path="/",
                entry_type="root",
                size=len(root_data),
                sha256=_sha256(root_data),
                directory_id=0,
                start_sector=root.start_sector,
            )
        ]
        for directory_id, path in sorted(
            paths.items(), key=lambda item: (item[1].casefold(), item[1])
        ):
            if directory_id == 0:
                continue
            entry = directory_entries[directory_id]
            if entry.object_type == 1:
                if entry.size != 0:
                    raise CFBError(f"storage {path!r} has nonzero stream size")
                inventory_entries.append(
                    InventoryEntry(
                        path=path,
                        entry_type="storage",
                        size=0,
                        sha256=None,
                        directory_id=directory_id,
                        start_sector=entry.start_sector,
                    )
                )
                continue

            if entry.size < self.header.mini_stream_cutoff:
                expected = (
                    entry.size + self.header.mini_sector_size - 1
                ) // self.header.mini_sector_size
                chain = self._follow_mini_chain(
                    entry.start_sector,
                    expected,
                    f"stream {path!r}",
                    mini_capacity,
                )
                for mini_sector_id in chain:
                    self._claim_mini_sector(mini_sector_id, path)
                payload = b"".join(
                    root_data[
                        mini_sector_id * self.header.mini_sector_size :
                        (mini_sector_id + 1) * self.header.mini_sector_size
                    ]
                    for mini_sector_id in chain
                )[: entry.size]
            else:
                payload, _ = self._read_regular_stream(
                    entry.start_sector,
                    entry.size,
                    f"stream {path!r}",
                    f"stream {path}",
                )
            extracted[path] = payload
            inventory_entries.append(
                InventoryEntry(
                    path=path,
                    entry_type="stream",
                    size=len(payload),
                    sha256=_sha256(payload),
                    directory_id=directory_id,
                    start_sector=entry.start_sector,
                )
            )

        inventory_entries.sort(
            key=lambda entry: (entry.path.casefold(), entry.path, entry.directory_id)
        )
        byte_regions, mini_regions = self._inventory_regions(root_data, root_chain)
        physical_regions, mini_physical_regions = self._physical_inventory(
            root_data, root_chain
        )
        return CFBInventory(
            signature_offset=self.base,
            cfb_length=self.cfb_end - self.base,
            major_version=self.header.major_version,
            minor_version=self.header.minor_version,
            sector_size=self.header.sector_size,
            mini_sector_size=self.header.mini_sector_size,
            sector_count=self.sector_count,
            entries=tuple(inventory_entries),
            physical_regions=physical_regions,
            mini_physical_regions=mini_physical_regions,
            byte_regions=byte_regions,
            mini_regions=mini_regions,
            _streams=MappingProxyType(dict(sorted(extracted.items()))),
        )


__all__ = [
    "ByteRegion",
    "CFBError",
    "CFBInventory",
    "CFB_SIGNATURE",
    "InventoryEntry",
    "discover_cfb_offset",
    "find_cfb_offsets",
    "inventory_cfb",
    "inventory_cfb_file",
    "parse_cfb",
    "parse_cfb_file",
]
