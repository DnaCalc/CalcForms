"""Coverage and anti-promotion checks for the .6 companion obligations."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/msforms-parity"))
sys.path.insert(0, str(ROOT / "tools/office-oracle"))
import facade_contract as facade
import msforms_facade_probe as probe
import msforms_member_oracle as oracle


class FacadeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = facade.load_base()
        cls.document = facade.build(cls.base)

    def test_canonical_artifact_is_exact(self):
        self.assertEqual((ROOT / facade.OUTPUT_PATH).read_bytes(), facade.encoded(self.document))
        self.assertFalse(self.document["summary"]["green"])
        self.assertEqual(len(self.document["type_shapes"]), 183)
        self.assertEqual(len({row["contract_ref"] for row in self.document["member_shapes"]}), 3632)

    def test_events_and_native_abi_are_not_fabricated_as_vba_methods(self):
        events = [row for row in self.document["member_shapes"] if row["binding_kind"] == "event_projection"]
        self.assertEqual(len(events), 380)
        self.assertTrue(all(item["source_shape"] == "Event" for row in events for item in row["accessor_shapes"]))
        font = [row for row in self.document["member_shapes"] if row["exact_owner_name"] == "IFont"]
        self.assertTrue(font)
        self.assertTrue(all(item["source_shape"].startswith("Native ABI") for row in font for item in row["accessor_shapes"]))

    def test_owner_coverage_is_not_reduced_to_representatives(self):
        projections = self.document["control_site_projections"]
        owners = {row["owner_name"] for row in projections}
        self.assertEqual(len(owners), 51)
        for name in ("TextBox", "TextBox2", "HTMLHidden", "HTMLHidden2", "Page", "UserForm"):
            self.assertIn(name, owners)
        for name in owners:
            self.assertEqual(sum(row["owner_name"] == name for row in projections), 52)
        events = self.document["host_event_applicability"]
        self.assertEqual(len(events), 204)
        self.assertEqual(sum(row["applicability"] == "observed_attachment" for row in events), 10)

    def test_cannot_credit_standalone_control_to_concrete_control(self):
        altered = copy.deepcopy(self.document)
        row = next(row for row in altered["control_site_projections"] if row["owner_name"] == "TextBox" and row["exact_name"] == "Name")
        row["implementation_status"] = "verified"
        row["implementation_evidence"] = [row["site_surface_ref"]]
        with self.assertRaisesRegex(ValueError, "exact source-derived obligations"):
            facade.validate(altered, self.base)

    def test_cannot_drop_versioned_or_hidden_family(self):
        altered = copy.deepcopy(self.document)
        altered["control_site_projections"] = [row for row in altered["control_site_projections"] if row["owner_name"] != "HTMLPassword2"]
        with self.assertRaises(ValueError):
            facade.validate(altered, self.base)

    def test_native_collision_retains_both_authorities(self):
        collisions = [row for row in self.document["control_site_projections"] if row["native_member_collision_ref"]]
        self.assertGreater(len(collisions), 0)
        self.assertTrue(all(row["native_member_collision_ref"] != row["site_surface_ref"] for row in collisions))

    def test_get_put_putref_and_default_are_distinct(self):
        row = next(row for row in self.document["member_shapes"] if row["exact_owner_name"] == "Label" and row["exact_member_name"] == "Picture")
        shapes = {item["accessor"]: item for item in row["accessor_shapes"]}
        self.assertEqual(set(shapes), {"get", "put", "putref"})
        self.assertEqual(shapes["put"]["source_shape"], "Property Let")
        self.assertEqual(shapes["putref"]["source_shape"], "Property Set")
        default_row = next(row for row in self.document["member_shapes"] if row["exact_owner_name"] == "TextBox" and row["exact_member_name"] == "Value")
        self.assertTrue(all(item["default_member"] for item in default_row["accessor_shapes"]))
        altered = copy.deepcopy(self.document)
        altered["member_shapes"][self.document["member_shapes"].index(row)]["accessor_shapes"].pop()
        with self.assertRaises(ValueError):
            facade.validate(altered, self.base)

    def test_no_invented_versioned_progid(self):
        row = next(row for row in self.document["progids"] if row["owner_name"] == "TextBox2")
        self.assertIsNone(row["prog_id"])
        row = next(row for row in self.document["progids"] if row["owner_name"] == "TextBox")
        self.assertEqual(row["prog_id"], "Forms.TextBox.1")

    def test_all_designer_accessors_have_independent_probes(self):
        manifest, targets = probe.definition()
        steps = [step for step in manifest["steps"] if step.get("target") in targets]
        self.assertEqual(len(steps), 38)
        self.assertEqual(len({step["id"] for step in steps}), 38)
        for obligation in self.document["designer_band_callability"]:
            probes = [step for step in steps if step["ledger_row_id"] == obligation["declaration_ref"]]
            self.assertEqual({step["operation"] for step in probes}, {"property_get", "property_set"})
            self.assertTrue(all(step["target"] == obligation["interface"] for step in probes))
        generated = probe.sources(manifest, targets)[oracle.RUNTIME_MODULE_NAME][1]
        self.assertIn("Case 2: Set FacadeTarget = W010MemberOracleForm.ProbeMultiPage.Pages(0)", generated)
        self.assertIn("FacadeTarget(0).DrawBuffer", generated)

    def test_v1_generation_remains_byte_identical_to_historical_capture(self):
        manifest = oracle.validate_manifest(probe.BASE_MANIFEST, ROOT)
        previous = ROOT / "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.5/captures/W010RepresentativeMemberOracleV1"
        self.assertEqual(oracle.generate_module_code(manifest).encode(), (previous / "generated-module-code.bas").read_bytes())
        self.assertEqual(oracle.generate_form_code(manifest).encode(), (previous / "generated-form-code.bas").read_bytes())


if __name__ == "__main__":
    unittest.main()
