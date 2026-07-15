from __future__ import annotations

import hashlib
import importlib
import json
from pathlib import Path
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest


MODULE_DIRECTORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE_DIRECTORY))
cfb = importlib.import_module("cfb_inventory")


def _header(
    *,
    fat_sector_count: int,
    first_directory_sector: int,
    first_minifat_sector: int = cfb.ENDOFCHAIN,
    minifat_sector_count: int = 0,
    first_difat_sector: int = cfb.ENDOFCHAIN,
    difat_sector_count: int = 0,
    difat: list[int] | None = None,
) -> bytes:
    result = bytearray(512)
    result[:8] = cfb.CFB_SIGNATURE
    struct.pack_into("<HHHH", result, 24, 0x003E, 3, 0xFFFE, 9)
    struct.pack_into("<H", result, 32, 6)
    struct.pack_into("<I", result, 40, 0)
    struct.pack_into("<I", result, 44, fat_sector_count)
    struct.pack_into("<I", result, 48, first_directory_sector)
    struct.pack_into("<I", result, 52, 0)
    struct.pack_into("<I", result, 56, 4096)
    struct.pack_into("<I", result, 60, first_minifat_sector)
    struct.pack_into("<I", result, 64, minifat_sector_count)
    struct.pack_into("<I", result, 68, first_difat_sector)
    struct.pack_into("<I", result, 72, difat_sector_count)
    values = list(difat or [])
    values.extend([cfb.FREESECT] * (109 - len(values)))
    struct.pack_into("<109I", result, 76, *values)
    return bytes(result)


def _directory_entry(
    name: str,
    object_type: int,
    *,
    left: int = cfb.NOSTREAM,
    right: int = cfb.NOSTREAM,
    child: int = cfb.NOSTREAM,
    color: int = 1,
    clsid: bytes = bytes(16),
    state_bits: int = 0,
    creation_time: int = 0,
    modified_time: int = 0,
    start_sector: int = cfb.ENDOFCHAIN,
    size: int = 0,
) -> bytes:
    result = bytearray(128)
    encoded_name = name.encode("utf-16-le") + b"\x00\x00"
    if len(encoded_name) > 64:
        raise AssertionError("test directory name is too long")
    result[: len(encoded_name)] = encoded_name
    struct.pack_into("<H", result, 64, len(encoded_name))
    result[66] = object_type
    result[67] = color
    struct.pack_into("<III", result, 68, left, right, child)
    if len(clsid) != 16:
        raise AssertionError("CLSID must contain 16 bytes")
    result[80:96] = clsid
    struct.pack_into("<IQQ", result, 96, state_bits, creation_time, modified_time)
    struct.pack_into("<I", result, 116, start_sector)
    struct.pack_into("<Q", result, 120, size)
    return bytes(result)


def _empty_directory_entry() -> bytes:
    result = bytearray(128)
    struct.pack_into(
        "<III", result, 68, cfb.NOSTREAM, cfb.NOSTREAM, cfb.NOSTREAM
    )
    return bytes(result)


def _mini_stream_cfb(
    payload: bytes = b"hello",
    *,
    nested: bool = True,
    prefix: bytes = b"FRX-prefix-at-byte-24!!\x00",
    extra_sector_marker: int | None = None,
    interior_free_sector: bool = False,
    trailing: bytes = b"",
) -> bytes:
    if len(prefix) != 24:
        raise AssertionError(len(prefix))
    mini_count = (len(payload) + 63) // 64
    if mini_count == 0:
        raise AssertionError("test helper expects a non-empty payload")
    if mini_count * 64 > 512:
        raise AssertionError("test helper supports one root mini-stream sector")

    fat = [cfb.FREESECT] * 128
    fat[0] = cfb.FATSECT
    fat[1] = cfb.ENDOFCHAIN
    fat[2] = cfb.ENDOFCHAIN
    fat[3] = cfb.ENDOFCHAIN
    sectors: list[bytes] = [b"", b"", b"", b""]
    if interior_free_sector and extra_sector_marker is not None:
        raise AssertionError("test allocation options are mutually exclusive")
    if extra_sector_marker is not None:
        fat[4] = extra_sector_marker
        sectors.append(bytes(512))
    if interior_free_sector:
        fat[1] = 5
        fat[4] = cfb.FREESECT
        fat[5] = cfb.ENDOFCHAIN
        sectors.extend(
            [
                bytes(512),
                b"".join(_empty_directory_entry() for _ in range(4)),
            ]
        )
    sectors[0] = struct.pack("<128I", *fat)

    if nested:
        directory = b"".join(
            [
                _directory_entry(
                    "Root Entry", 5, child=1, start_sector=2, size=mini_count * 64
                ),
                _directory_entry("Frame", 1, child=2, start_sector=0),
                _directory_entry("Tiny", 2, start_sector=0, size=len(payload)),
                _empty_directory_entry(),
            ]
        )
    else:
        directory = b"".join(
            [
                _directory_entry(
                    "Root Entry", 5, child=1, start_sector=2, size=mini_count * 64
                ),
                _directory_entry("Tiny", 2, start_sector=0, size=len(payload)),
                _empty_directory_entry(),
                _empty_directory_entry(),
            ]
        )
    sectors[1] = directory
    sectors[2] = payload.ljust(512, b"\x00")
    minifat = [cfb.FREESECT] * 128
    for index in range(mini_count):
        minifat[index] = index + 1 if index + 1 < mini_count else cfb.ENDOFCHAIN
    sectors[3] = struct.pack("<128I", *minifat)
    header = _header(
        fat_sector_count=1,
        first_directory_sector=1,
        first_minifat_sector=3,
        minifat_sector_count=1,
        difat=[0],
    )
    return prefix + header + b"".join(sectors) + trailing


def _regular_stream_cfb() -> tuple[bytes, bytes]:
    payload = bytes(range(256)) * 16
    fat = [cfb.FREESECT] * 128
    fat[0] = cfb.FATSECT
    fat[1] = cfb.ENDOFCHAIN
    for sector_id in range(2, 10):
        fat[sector_id] = sector_id + 1 if sector_id < 9 else cfb.ENDOFCHAIN
    directory = b"".join(
        [
            _directory_entry("Root Entry", 5, child=1),
            _directory_entry("Large", 2, start_sector=2, size=len(payload)),
            _empty_directory_entry(),
            _empty_directory_entry(),
        ]
    )
    sectors = [struct.pack("<128I", *fat), directory]
    sectors.extend(payload[offset : offset + 512] for offset in range(0, 4096, 512))
    result = _header(
        fat_sector_count=1,
        first_directory_sector=1,
        difat=[0],
    ) + b"".join(sectors)
    return result, payload


def _directory_only_cfb(entries: list[bytes]) -> bytes:
    if not 1 <= len(entries) <= 4:
        raise AssertionError("version 3 test directory supports one sector")
    directory = b"".join(
        entries + [_empty_directory_entry()] * (4 - len(entries))
    )
    fat = [cfb.FREESECT] * 128
    fat[0] = cfb.FATSECT
    fat[1] = cfb.ENDOFCHAIN
    return (
        _header(
            fat_sector_count=1,
            first_directory_sector=1,
            difat=[0],
        )
        + struct.pack("<128I", *fat)
        + directory
    )


def _external_difat_cfb(*, cyclic: bool = False) -> bytes:
    fat_sector_ids = list(range(110))
    difat_sector_id = 110
    directory_sector_id = 111
    fat_entries = [cfb.FREESECT] * (110 * 128)
    for sector_id in fat_sector_ids:
        fat_entries[sector_id] = cfb.FATSECT
    fat_entries[difat_sector_id] = cfb.DIFSECT
    fat_entries[directory_sector_id] = cfb.ENDOFCHAIN

    sectors = [bytes(512) for _ in range(112)]
    for index, sector_id in enumerate(fat_sector_ids):
        entries = fat_entries[index * 128 : (index + 1) * 128]
        sectors[sector_id] = struct.pack("<128I", *entries)
    difat_values = [109] + [cfb.FREESECT] * 126
    difat_values.append(difat_sector_id if cyclic else cfb.ENDOFCHAIN)
    sectors[difat_sector_id] = struct.pack("<128I", *difat_values)
    sectors[directory_sector_id] = b"".join(
        [
            _directory_entry("Root Entry", 5),
            _empty_directory_entry(),
            _empty_directory_entry(),
            _empty_directory_entry(),
        ]
    )
    header = _header(
        fat_sector_count=110,
        first_directory_sector=directory_sector_id,
        first_difat_sector=difat_sector_id,
        difat_sector_count=2 if cyclic else 1,
        difat=list(range(109)),
    )
    return header + b"".join(sectors)


def _version_four_cfb() -> bytes:
    header = bytearray(4096)
    header[:8] = cfb.CFB_SIGNATURE
    struct.pack_into("<HHHH", header, 24, 0x003E, 4, 0xFFFE, 12)
    struct.pack_into("<H", header, 32, 6)
    struct.pack_into("<I", header, 40, 1)
    struct.pack_into("<I", header, 44, 1)
    struct.pack_into("<I", header, 48, 1)
    struct.pack_into("<I", header, 56, 4096)
    struct.pack_into("<I", header, 60, cfb.ENDOFCHAIN)
    struct.pack_into("<I", header, 68, cfb.ENDOFCHAIN)
    struct.pack_into("<I", header, 76, 0)
    struct.pack_into("<108I", header, 80, *([cfb.FREESECT] * 108))
    fat = [cfb.FREESECT] * 1024
    fat[0] = cfb.FATSECT
    fat[1] = cfb.ENDOFCHAIN
    directory = _directory_entry("Root Entry", 5) + b"".join(
        _empty_directory_entry() for _ in range(31)
    )
    return bytes(header) + struct.pack("<1024I", *fat) + directory


class CFBInventoryTests(unittest.TestCase):
    def test_discovers_embedded_cfb_and_reconstructs_nested_stream(self) -> None:
        raw = _mini_stream_cfb()

        self.assertEqual(cfb.find_cfb_offsets(raw), (24,))
        self.assertEqual(cfb.discover_cfb_offset(raw), 24)
        document = cfb.parse_cfb(raw)

        self.assertEqual(document.signature_offset, 24)
        self.assertEqual(document.cfb_length, 5 * 512)
        self.assertEqual(document.read_stream("/Frame/Tiny"), b"hello")
        self.assertEqual(tuple(document.streams), ("/Frame/Tiny",))
        entries = {entry.path: entry for entry in document.entries}
        self.assertEqual(set(entries), {"/", "/Frame", "/Frame/Tiny"})
        self.assertEqual(entries["/Frame"].entry_type, "storage")
        self.assertIsNone(entries["/Frame"].sha256)
        self.assertEqual(entries["/Frame/Tiny"].size, 5)
        self.assertEqual(
            entries["/Frame/Tiny"].sha256, hashlib.sha256(b"hello").hexdigest()
        )

    def test_serializable_inventory_is_deterministic(self) -> None:
        raw = _mini_stream_cfb(nested=False)
        first = cfb.inventory_cfb(raw)
        second = cfb.parse_cfb(raw, signature_offset=24).to_dict()

        self.assertEqual(first, second)
        self.assertEqual(
            json.dumps(first, sort_keys=True, separators=(",", ":")),
            json.dumps(second, sort_keys=True, separators=(",", ":")),
        )
        self.assertEqual(first["entries"][1]["path"], "/Tiny")

    def test_file_api_reads_stream_without_target_fixture_dependency(self) -> None:
        raw = _mini_stream_cfb(payload=b"fixture")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "embedded.frx")
            path.write_bytes(raw)
            document = cfb.parse_cfb_file(path)
            inventory = cfb.inventory_cfb_file(path)

        self.assertEqual(document.read_stream("/Frame/Tiny"), b"fixture")
        self.assertEqual(inventory, document.to_dict())

    def test_extracts_regular_fat_stream(self) -> None:
        raw, payload = _regular_stream_cfb()
        document = cfb.parse_cfb(raw, signature_offset=0)

        self.assertEqual(document.read_stream("/Large"), payload)
        large = next(entry for entry in document.entries if entry.path == "/Large")
        self.assertEqual(large.size, 4096)
        self.assertEqual(large.sha256, hashlib.sha256(payload).hexdigest())
        self.assertEqual(document.byte_regions, ())

    def test_classifies_prefix_free_sector_and_trailing_bytes(self) -> None:
        raw = _mini_stream_cfb(
            interior_free_sector=True,
            trailing=bytes(512) + b"tail",
        )
        document = cfb.parse_cfb(raw)

        regions = {region.classification: region for region in document.byte_regions}
        self.assertEqual(regions["prefix_before_cfb"].length, 24)
        self.assertEqual(regions["unallocated_free_sector"].sector_id, 4)
        self.assertEqual(regions["unallocated_free_sector"].length, 512)
        self.assertEqual(
            regions["trailing_after_cfb_sector_boundary"].length, 516
        )

    def test_physical_regions_partition_every_supplied_byte_once(self) -> None:
        raw = _mini_stream_cfb(
            interior_free_sector=True,
            trailing=bytes(512) + b"tail",
        )
        document = cfb.parse_cfb(raw)

        cursor = 0
        for region in document.physical_regions:
            self.assertEqual(region.offset, cursor)
            self.assertGreater(region.length, 0)
            cursor += region.length
        self.assertEqual(cursor, len(raw))
        self.assertEqual(
            document.physical_regions[0].classification, "prefix_before_cfb"
        )
        self.assertEqual(
            document.physical_regions[1].classification, "cfb_header_sector"
        )
        allocated = [
            region
            for region in document.physical_regions
            if region.classification == "allocated_cfb_sector"
        ]
        self.assertTrue(allocated)
        self.assertTrue(all(region.owner for region in allocated))

    def test_allocated_sector_and_mini_stream_slack_are_hashed(self) -> None:
        original = _mini_stream_cfb(payload=b"hello")
        mutated = bytearray(original)
        root_sector_offset = 24 + 3 * 512
        mutated[root_sector_offset + 5] ^= 0x5A

        before = cfb.parse_cfb(original)
        after = cfb.parse_cfb(mutated)
        self.assertEqual(before.read_stream("/Frame/Tiny"), b"hello")
        self.assertEqual(after.read_stream("/Frame/Tiny"), b"hello")
        self.assertEqual(before.byte_regions, after.byte_regions)

        before_root = next(
            region
            for region in before.physical_regions
            if region.sector_id == 2
        )
        after_root = next(
            region
            for region in after.physical_regions
            if region.sector_id == 2
        )
        self.assertNotEqual(before_root.sha256, after_root.sha256)
        self.assertEqual(before_root.owner, "root mini-stream")

        before_mini = next(
            region
            for region in before.mini_physical_regions
            if region.mini_sector_id == 0
        )
        after_mini = next(
            region
            for region in after.mini_physical_regions
            if region.mini_sector_id == 0
        )
        self.assertEqual(before_mini.classification, "allocated_mini_sector")
        self.assertEqual(before_mini.owner, "/Frame/Tiny")
        self.assertNotEqual(before_mini.sha256, after_mini.sha256)

    def test_sector_aligned_outer_suffix_is_trailing_even_beyond_fat_capacity(
        self,
    ) -> None:
        raw, _ = _regular_stream_cfb()
        suffix = bytes(119 * 512)
        document = cfb.parse_cfb(raw + suffix, signature_offset=0)

        self.assertEqual(document.cfb_length, len(raw))
        trailing = next(
            region
            for region in document.byte_regions
            if region.classification == "trailing_after_cfb_sector_boundary"
        )
        self.assertEqual(trailing.length, len(suffix))

    def test_rejects_unreferenced_allocated_sector(self) -> None:
        with self.assertRaisesRegex(cfb.CFBError, "no reachable owner"):
            cfb.parse_cfb(
                _mini_stream_cfb(extra_sector_marker=cfb.ENDOFCHAIN)
            )

    def test_rejects_orphan_fat_cycle_overlap_and_out_of_bounds_pointer(self) -> None:
        for marker in (4, 1, 99):
            with self.subTest(marker=marker), self.assertRaises(cfb.CFBError):
                cfb.parse_cfb(_mini_stream_cfb(extra_sector_marker=marker))

    def test_classifies_unallocated_mini_sector(self) -> None:
        raw = bytearray(_mini_stream_cfb(payload=b"A" * 65))
        # Make the root mini-stream one slot larger without allocating it.
        root_size_offset = 24 + (1 + 1) * 512 + 120
        struct.pack_into("<Q", raw, root_size_offset, 192)
        document = cfb.parse_cfb(raw)

        free = next(
            region
            for region in document.mini_regions
            if region.classification == "unallocated_free_mini_sector"
        )
        self.assertEqual(free.mini_sector_id, 2)
        self.assertEqual(free.length, 64)
        physical_free = next(
            region
            for region in document.mini_physical_regions
            if region.mini_sector_id == 2
        )
        self.assertEqual(
            physical_free.classification, "unallocated_free_mini_sector"
        )
        self.assertIsNone(physical_free.owner)

    def test_reads_external_difat_sector(self) -> None:
        document = cfb.parse_cfb(_external_difat_cfb(), signature_offset=0)

        self.assertEqual(document.sector_count, 112)
        self.assertEqual([entry.path for entry in document.entries], ["/"])
        self.assertEqual(document.byte_regions, ())

    def test_reads_version_four_sector_layout(self) -> None:
        document = cfb.parse_cfb(_version_four_cfb(), signature_offset=0)

        self.assertEqual(document.major_version, 4)
        self.assertEqual(document.sector_size, 4096)
        self.assertEqual(document.sector_count, 2)
        self.assertEqual([entry.path for entry in document.entries], ["/"])

    def test_rejects_nonzero_version_four_header_padding(self) -> None:
        raw = bytearray(_version_four_cfb())
        raw[512] = 1
        with self.assertRaisesRegex(cfb.CFBError, "padding must be zero"):
            cfb.parse_cfb(raw, signature_offset=0)

    def test_rejects_ambiguous_signature_discovery(self) -> None:
        raw = _mini_stream_cfb() + _regular_stream_cfb()[0]
        with self.assertRaisesRegex(cfb.CFBError, "multiple plausible"):
            cfb.discover_cfb_offset(raw)

    def test_rejects_missing_or_explicitly_wrong_signature(self) -> None:
        with self.assertRaisesRegex(cfb.CFBError, "no plausible"):
            cfb.parse_cfb(bytes(1024))
        with self.assertRaisesRegex(cfb.CFBError, "absent at offset"):
            cfb.parse_cfb(_mini_stream_cfb(), signature_offset=0)

    def test_rejects_truncated_header_and_sector_area(self) -> None:
        with self.assertRaisesRegex(cfb.CFBError, "no plausible"):
            cfb.parse_cfb(cfb.CFB_SIGNATURE + bytes(100))
        header_only = _header(
            fat_sector_count=1,
            first_directory_sector=1,
            difat=[0],
        )
        with self.assertRaisesRegex(cfb.CFBError, "header sector and one data sector"):
            cfb.parse_cfb(header_only, signature_offset=0)

    def test_rejects_wrong_minor_version(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        struct.pack_into("<H", raw, 24 + 24, 0)
        with self.assertRaisesRegex(cfb.CFBError, "minor version must be 0x003E"):
            cfb.parse_cfb(raw)

    def test_rejects_out_of_bounds_fat_sector(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        struct.pack_into("<I", raw, 24 + 76, 99)
        with self.assertRaisesRegex(cfb.CFBError, "outside"):
            cfb.parse_cfb(raw)

    def test_rejects_unlisted_special_allocation_marker(self) -> None:
        raw = _mini_stream_cfb(extra_sector_marker=cfb.FATSECT)
        with self.assertRaisesRegex(cfb.CFBError, "absent from DIFAT"):
            cfb.parse_cfb(raw)

    def test_rejects_directory_fat_chain_cycle(self) -> None:
        raw, _ = _regular_stream_cfb()
        damaged = bytearray(raw)
        # FAT sector starts immediately after the 512-byte header; entry 1 owns
        # the directory sector and is changed from ENDOFCHAIN to itself.
        struct.pack_into("<I", damaged, 512 + 4, 1)
        with self.assertRaisesRegex(cfb.CFBError, "directory chain cycle"):
            cfb.parse_cfb(damaged, signature_offset=0)

    def test_rejects_regular_stream_chain_overrun(self) -> None:
        raw, _ = _regular_stream_cfb()
        damaged = bytearray(raw)
        struct.pack_into("<I", damaged, 512 + 9 * 4, 2)
        with self.assertRaisesRegex(cfb.CFBError, "overruns its expected"):
            cfb.parse_cfb(damaged, signature_offset=0)

    def test_rejects_nonfree_fat_entry_beyond_physical_eof(self) -> None:
        raw, _ = _regular_stream_cfb()
        damaged = bytearray(raw)
        struct.pack_into("<I", damaged, 512 + 127 * 4, cfb.ENDOFCHAIN)
        with self.assertRaisesRegex(cfb.CFBError, "physical sectors are available"):
            cfb.parse_cfb(damaged, signature_offset=0)

    def test_rejects_minifat_chain_cycle(self) -> None:
        raw = bytearray(_mini_stream_cfb(payload=b"A" * 129))
        minifat_offset = 24 + (3 + 1) * 512
        struct.pack_into("<I", raw, minifat_offset + 4, 0)
        with self.assertRaisesRegex(cfb.CFBError, "cycle at mini-sector"):
            cfb.parse_cfb(raw)

    def test_rejects_partial_root_ministream(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        root_size_offset = 24 + (1 + 1) * 512 + 120
        struct.pack_into("<Q", raw, root_size_offset, 65)
        with self.assertRaisesRegex(cfb.CFBError, "whole number of mini-sectors"):
            cfb.parse_cfb(raw)

    def test_rejects_minifat_allocation_beyond_root_capacity(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        minifat_offset = 24 + (3 + 1) * 512
        struct.pack_into("<I", raw, minifat_offset + 5 * 4, cfb.ENDOFCHAIN)
        with self.assertRaisesRegex(cfb.CFBError, "allocated beyond"):
            cfb.parse_cfb(raw)

    def test_rejects_unowned_minifat_allocation_and_cycle(self) -> None:
        root_size_offset = 24 + (1 + 1) * 512 + 120
        minifat_offset = 24 + (3 + 1) * 512

        orphan = bytearray(_mini_stream_cfb())
        struct.pack_into("<Q", orphan, root_size_offset, 128)
        struct.pack_into("<I", orphan, minifat_offset + 4, cfb.ENDOFCHAIN)
        with self.assertRaisesRegex(cfb.CFBError, "no reachable owner"):
            cfb.parse_cfb(orphan)

        cycle = bytearray(_mini_stream_cfb())
        struct.pack_into("<Q", cycle, root_size_offset, 192)
        struct.pack_into("<I", cycle, minifat_offset + 4, 2)
        struct.pack_into("<I", cycle, minifat_offset + 8, 1)
        with self.assertRaisesRegex(cfb.CFBError, "no reachable owner"):
            cfb.parse_cfb(cycle)

    def test_rejects_directory_sibling_cycle(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        directory_sector_offset = 24 + (1 + 1) * 512
        storage_entry_offset = directory_sector_offset + 128
        struct.pack_into("<I", raw, storage_entry_offset + 68, 1)
        with self.assertRaisesRegex(cfb.CFBError, "sibling-tree cycle"):
            cfb.parse_cfb(raw)

    def test_rejects_directory_name_that_cannot_form_canonical_path(self) -> None:
        raw = bytearray(_mini_stream_cfb())
        directory_sector_offset = 24 + (1 + 1) * 512
        stream_entry_offset = directory_sector_offset + 2 * 128
        raw[stream_entry_offset : stream_entry_offset + 128] = _directory_entry(
            "Bad/Name", 2, start_sector=0, size=5
        )
        with self.assertRaisesRegex(cfb.CFBError, "prohibited"):
            cfb.parse_cfb(raw)

    def test_uses_cfb_length_first_name_comparator_not_python_casefold(self) -> None:
        raw = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("ß", 2, right=2),
                _directory_entry("ss", 2, color=0),
            ]
        )
        document = cfb.parse_cfb(raw, signature_offset=0)

        self.assertEqual(set(document.streams), {"/ß", "/ss"})

    def test_uses_unicode_simple_uppercase_for_greek_cfb_names(self) -> None:
        raw = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("\u1f80", 2, right=2),
                _directory_entry("\u1f88", 2, color=0),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "duplicate"):
            cfb.parse_cfb(raw, signature_offset=0)

    def test_claims_required_version_four_range_lock_sector(self) -> None:
        parser = object.__new__(cfb._Parser)
        parser.base = 0
        parser.cfb_end = 0x80001000
        parser.header = SimpleNamespace(major_version=4, sector_size=4096)
        parser.sector_count = 0x80000
        parser.fat = {0x7FFFE: cfb.ENDOFCHAIN}
        parser.claimed_sectors = {}

        parser._claim_range_lock_sector_if_required()

        self.assertEqual(parser.claimed_sectors, {0x7FFFE: "range lock"})

    def test_rejects_misordered_directory_sibling_tree(self) -> None:
        raw = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("Long", 2, right=2),
                _directory_entry("A", 2, color=0),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "misordered"):
            cfb.parse_cfb(raw, signature_offset=0)

    def test_rejects_red_directory_tree_root_and_consecutive_red_nodes(self) -> None:
        red_root = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("A", 2, color=0),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "must be black"):
            cfb.parse_cfb(red_root, signature_offset=0)

        red_pair = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("A", 2, right=2),
                _directory_entry("B", 2, color=0, right=3),
                _directory_entry("C", 2, color=0),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "consecutive red"):
            cfb.parse_cfb(red_pair, signature_offset=0)

    def test_root_entry_color_and_classical_black_height_are_not_constraints(
        self,
    ) -> None:
        red_root_entry = _directory_only_cfb(
            [_directory_entry("Root Entry", 5, color=0)]
        )
        red_root = cfb.parse_cfb(red_root_entry, signature_offset=0)
        self.assertEqual([entry.path for entry in red_root.entries], ["/"])

        unequal_black_height = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("B", 2, left=2, right=3),
                _directory_entry("A", 2, color=1),
                _directory_entry("C", 2, color=0),
            ]
        )
        uneven = cfb.parse_cfb(unequal_black_height, signature_offset=0)
        self.assertEqual(set(uneven.streams), {"/A", "/B", "/C"})

    def test_rejects_invalid_unused_directory_entry_layout(self) -> None:
        raw = bytearray(
            _directory_only_cfb(
                [
                    _directory_entry("Root Entry", 5, child=1),
                    _directory_entry("A", 2),
                ]
            )
        )
        directory_offset = 2 * 512
        struct.pack_into("<I", raw, directory_offset + 2 * 128 + 68, 0)
        with self.assertRaisesRegex(cfb.CFBError, "not zero-filled"):
            cfb.parse_cfb(raw, signature_offset=0)

    def test_rejects_invalid_stream_storage_and_root_directory_fields(self) -> None:
        invalid_stream = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("A", 2, clsid=b"X" + bytes(15)),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "nonzero CLSID"):
            cfb.parse_cfb(invalid_stream, signature_offset=0)

        invalid_storage = _directory_only_cfb(
            [
                _directory_entry("Root Entry", 5, child=1),
                _directory_entry("A", 1, start_sector=77),
            ]
        )
        with self.assertRaisesRegex(cfb.CFBError, "nonzero starting sector"):
            cfb.parse_cfb(invalid_storage, signature_offset=0)

        invalid_root = _directory_only_cfb(
            [_directory_entry("Root Entry", 5, creation_time=1)]
        )
        with self.assertRaisesRegex(cfb.CFBError, "creation time must be zero"):
            cfb.parse_cfb(invalid_root, signature_offset=0)

    def test_rejects_difat_chain_cycle(self) -> None:
        with self.assertRaisesRegex(cfb.CFBError, "DIFAT chain cycle"):
            cfb.parse_cfb(_external_difat_cfb(cyclic=True), signature_offset=0)

    def test_rejects_multiply_allocated_stream_sector(self) -> None:
        raw = bytearray(_regular_stream_cfb()[0])
        directory_offset = (1 + 1) * 512
        second_stream = _directory_entry(
            "Other", 2, color=0, start_sector=2, size=4096
        )
        raw[directory_offset + 2 * 128 : directory_offset + 3 * 128] = second_stream
        # Make the first stream's right sibling point to the second stream.
        struct.pack_into("<I", raw, directory_offset + 128 + 72, 2)
        with self.assertRaisesRegex(cfb.CFBError, "multiply allocated"):
            cfb.parse_cfb(raw, signature_offset=0)


if __name__ == "__main__":
    unittest.main()
