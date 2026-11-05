"""Adversarial tests for the deterministic VBA public-surface extractor."""

from __future__ import annotations

import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
TOOL_ROOT = REPO_ROOT / "tools" / "msforms-parity"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))

from vba_surface import SurfaceError, extract_surface  # noqa: E402


CURRENT_MODULE_NAMES = [
    "CalcFormsModel",
    "IOxControl",
    "IOxControlHost",
    "IOxControlContainer",
    "OxControlCore",
    "Controls",
    "ReturnInteger",
    "ReturnBoolean",
    "Label",
    "OxTextService",
    "TextBox",
    "CommandButton",
    "CheckBox",
    "ListBox",
    "ComboBox",
    "Frame",
    "Image",
    "MultiPage",
    "Page",
    "Pages",
    "SpinButton",
    "ScrollBar",
    "Tab",
    "Tabs",
    "TabStrip",
    "ToggleButton",
    "OptionButtonControl",
    "UserForm",
    "OxAccessibilityService",
    "OxFrmMaterializer",
    "OxInteractionManager",
    "OxReducer",
    "OxTheme",
    "OxControlPaint",
    "OxSceneBuilder",
    "CalcForms",
    "CalcFormsSmokeForm",
]

PROJECT_PREFIX = '''<Project Sdk="CalcVBA.Sdk/0.1.0">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <ProjectName>CalcForms</ProjectName>
  </PropertyGroup>
'''
PROJECT_SUFFIX = "</Project>\n"


class TemporaryVbaProject:
    """Small on-disk fixture because basproj containment is part of the contract."""

    def __init__(self, test: unittest.TestCase) -> None:
        self.test = test
        self._temporary = tempfile.TemporaryDirectory()
        test.addCleanup(self._temporary.cleanup)
        self.root = Path(self._temporary.name)
        self.project = self.root / "Fixture.basproj"

    def source(self, name: str, body: str) -> Path:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(body).lstrip(), encoding="utf-8", newline="\n")
        return path

    def manifest(self, entries: list[tuple[str, str]]) -> Path:
        item_xml = "\n".join(
            f'    <{kind} Include="{include}" />' for kind, include in entries
        )
        self.project.write_text(
            PROJECT_PREFIX
            + "  <ItemGroup>\n"
            + item_xml
            + "\n  </ItemGroup>\n"
            + PROJECT_SUFFIX,
            encoding="utf-8",
            newline="\n",
        )
        return self.project

    def extract(self, entries: list[tuple[str, str]]) -> dict:
        return extract_surface(self.root, self.manifest(entries))


class VbaSurfaceFixtureTests(unittest.TestCase):
    maxDiff = None

    def test_multiline_comments_strings_brackets_and_full_parameter_shapes(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "FixtureClass.cls",
            r'''
            Attribute VB_Name = "FixtureClass"
            Attribute VB_Exposed = True
            Attribute VB_Creatable = False
            Option Explicit
            ' An apostrophe in a string is data; this whole line is a comment.
            Rem This old-style comment is ignored too.

            Public Function Echo( _
                Optional ByVal text As String = "left,'right,""quoted""", _
                ParamArray tail() As Variant) As String ' trailing comment
            End Function

            Public Function [Exit](ByVal [By] As String) As Boolean
            End Function

            Public Property Get Item(ByVal Index As Long) As Object
            End Property
            Public Property Set Item(ByVal Index As Long, ByVal rhs As Object)
            End Property
            Attribute Item.VB_UserMemId = 0
            Attribute Item.VB_Description = "default ""item"""

            Public Function _NewEnum() As Object
            End Function
            Attribute _NewEnum.VB_UserMemId = -4
            ''',
        )

        surface = fixture.extract([("ClassModule", "FixtureClass.cls")])
        module = surface["modules"][0]
        declarations = {(row["name"], row["kind"]): row for row in module["declarations"]}

        self.assertEqual("FixtureClass", module["name"])
        self.assertTrue(module["project_declared_exposed"])
        self.assertFalse(module["project_declared_creatable"])
        self.assertEqual(True, module["attributes"]["VB_Exposed"])

        echo = declarations[("Echo", "function")]
        self.assertEqual((8, 10), (echo["source"]["start_line"], echo["source"]["end_line"]))
        self.assertEqual("String", echo["return_type"])
        self.assertEqual(2, len(echo["parameters"]))
        optional, tail = echo["parameters"]
        self.assertEqual(
            {
                "name": "text",
                "passing": "byval",
                "optional": True,
                "param_array": False,
                "array": False,
                "type": "String",
                "default": '"left,\'right,""quoted"""',
            },
            {key: optional[key] for key in (
                "name", "passing", "optional", "param_array", "array", "type", "default"
            )},
        )
        self.assertEqual(
            ("tail", "byref", False, True, True, "Variant", None),
            tuple(
                tail[key]
                for key in (
                    "name",
                    "passing",
                    "optional",
                    "param_array",
                    "array",
                    "type",
                    "default",
                )
            ),
        )

        bracketed = declarations[("Exit", "function")]
        self.assertTrue(bracketed["bracketed_name"])
        self.assertEqual("By", bracketed["parameters"][0]["name"])

        item_get = declarations[("Item", "property_get")]
        item_set = declarations[("Item", "property_set")]
        self.assertFalse(item_get["default_member"])
        self.assertEqual(["Index"], [row["name"] for row in item_get["parameters"]])
        self.assertEqual(
            ["Index", "rhs"], [row["name"] for row in item_set["parameters"]]
        )
        for accessor in (item_get, item_set):
            self.assertEqual(0, accessor["member_attributes"]["VB_UserMemId"])
            self.assertEqual(
                'default "item"', accessor["member_attributes"]["VB_Description"]
            )
        self.assertEqual(
            -4,
            declarations[("_NewEnum", "function")]["member_attributes"][
                "VB_UserMemId"
            ],
        )
        self.assertEqual(1, surface["summary"]["multiline_public_signatures"])
        self.assertEqual(1, surface["summary"]["bracketed_public_names"])
        self.assertEqual(1, surface["summary"]["optional_parameters"])
        self.assertEqual(1, surface["summary"]["param_arrays"])
        self.assertEqual(3, surface["summary"]["module_attributes"])
        self.assertEqual(5, surface["summary"]["public_declarations"])
        self.assertEqual(5, surface["summary"]["member_attributes"])

    def test_option_private_module_retains_rows_but_removes_project_exposure(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Secret.bas",
            '''
            Attribute VB_Name = "Secret"
            Option Private Module
            Public Sub StillPartOfTheExtractedSurface()
            End Sub
            Const ImplicitModuleConstant = 1
            Public Const ExplicitConstant As Long = 2
            ''',
        )

        surface = fixture.extract([("Module", "Secret.bas")])
        module = surface["modules"][0]
        self.assertTrue(module["option_private_module"])
        self.assertFalse(module["project_declared_exposed"])
        self.assertEqual(
            ["StillPartOfTheExtractedSurface", "ExplicitConstant"],
            [row["name"] for row in module["declarations"]],
        )

    def test_malformed_option_private_spelling_cannot_leave_module_exposed(self) -> None:
        for source_line in (
            "Option Private Module:",
            "Option Private Module Extra",
            "Option Private",
        ):
            with self.subTest(source_line=source_line):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Secret.bas",
                    'Attribute VB_Name = "Secret"\n'
                    + source_line
                    + "\nPublic Sub Visible()\nEnd Sub\n",
                )
                with self.assertRaisesRegex(
                    SurfaceError, "unsupported Option Private spelling"
                ):
                    fixture.extract([("Module", "Secret.bas")])

    def test_orphan_member_attribute_is_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Orphan.cls",
            '''
            Attribute VB_Name = "Orphan"
            Attribute Missing.VB_UserMemId = 0
            Public Sub Present()
            End Sub
            ''',
        )
        with self.assertRaisesRegex(SurfaceError, "orphan member Attribute targets.*missing"):
            fixture.extract([("ClassModule", "Orphan.cls")])

    def test_duplicate_module_attribute_is_case_insensitively_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Duplicate.bas",
            '''
            Attribute VB_Name = "First"
            Attribute vb_name = "Second"
            ''',
        )
        with self.assertRaisesRegex(SurfaceError, "duplicate vb_name"):
            fixture.extract([("Module", "Duplicate.bas")])

    def test_duplicate_member_attribute_is_case_insensitively_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Duplicate.cls",
            '''
            Attribute VB_Name = "Duplicate"
            Attribute Item.VB_UserMemId = 0
            Attribute item.vb_usermemid = -4
            Public Property Get Item() As Variant
            End Property
            ''',
        )
        with self.assertRaisesRegex(SurfaceError, "duplicate item.vb_usermemid"):
            fixture.extract([("ClassModule", "Duplicate.cls")])

    def test_unknown_public_syntax_is_never_silently_dropped(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Unknown.bas",
            '''
            Attribute VB_Name = "Unknown"
            Public Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long
            ''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "unparsed externally visible declaration.*Public Declare"
        ):
            fixture.extract([("Module", "Unknown.bas")])

    def test_bare_declare_is_public_by_default_and_never_silently_dropped(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Unknown.bas",
            '''
            Attribute VB_Name = "Unknown"
            Declare PtrSafe Function GetTickCount Lib "kernel32" () As Long
            ''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "unparsed externally visible declaration.*Declare PtrSafe"
        ):
            fixture.extract([("Module", "Unknown.bas")])

    def test_conditional_compilation_cannot_hide_or_duplicate_public_surface(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Conditional.bas",
            '''
            Attribute VB_Name = "Conditional"
            #If False Then
            Public Sub HiddenFromThisBuild()
            End Sub
            #End If
            ''',
        )
        with self.assertRaisesRegex(SurfaceError, "conditional compilation is unsupported"):
            fixture.extract([("Module", "Conditional.bas")])

    def test_module_default_type_ranges_cannot_change_omitted_signature_types(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Defaults.bas",
            '''Attribute VB_Name = "Defaults"
DefInt A-Z
Public Function Alpha()
End Function
''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "module default-type statements are unsupported"
        ):
            fixture.extract([("Module", "Defaults.bas")])

    def test_module_identity_attributes_reject_truthy_nonboolean_values(self) -> None:
        cases = {
            "quoted_exposed": ('Attribute VB_Exposed = "False"', "unquoted Boolean"),
            "numeric_creatable": ("Attribute VB_Creatable = 0", "unquoted Boolean"),
            "boolean_name": ("Attribute VB_Name = True", "quoted string"),
            "unquoted_name": ("Attribute VB_Name = Thing", "quoted string"),
            "empty_name": ('Attribute VB_Name = ""', "valid VBA identifier"),
            "spaced_name": ('Attribute VB_Name = "Foo Bar"', "valid VBA identifier"),
            "dotted_name": ('Attribute VB_Name = "Foo.Bar"', "valid VBA identifier"),
        }
        for label, (attribute, expected) in cases.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source("Typed.bas", attribute + "\n")
                with self.assertRaisesRegex(SurfaceError, expected):
                    fixture.extract([("Module", "Typed.bas")])

    def test_module_attributes_follow_pinned_physical_line_rules(self) -> None:
        cases = {
            "commented": "Attribute VB_Exposed = True ' not accepted by CalcVBA",
            "continued": "Attribute VB_Exposed = _\nTrue",
        }
        for label, attribute in cases.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Typed.cls",
                    'Attribute VB_Name = "Typed"\n' + attribute + "\n",
                )
                with self.assertRaisesRegex(
                    SurfaceError, "module Attribute"
                ):
                    fixture.extract([("ClassModule", "Typed.cls")])

    def test_comment_cannot_launder_an_invalid_vba_line_continuation(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Typed.cls",
            '''Attribute VB_Name = "Typed"
Public Function Echo( _ ' this prevents a real VBA continuation
    ByVal Value As Long) As Long
End Function
''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "comment after VBA line-continuation underscore"
        ):
            fixture.extract([("ClassModule", "Typed.cls")])

    def test_module_metadata_cannot_be_smuggled_from_nested_vba_scopes(self) -> None:
        cases = {
            "procedure_attribute": """Public Sub X()
Attribute VB_Exposed = True
End Sub""",
            "enum_attribute": """Public Enum E
Attribute VB_Creatable = True
Value = 1
End Enum""",
            "procedure_option": """Public Sub X()
Option Private Module
End Sub""",
        }
        for label, nested_source in cases.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Nested.bas",
                    'Attribute VB_Name = "Nested"\n' + nested_source + "\n",
                )
                with self.assertRaisesRegex(
                    SurfaceError, "only valid at module scope"
                ):
                    fixture.extract([("Module", "Nested.bas")])

    def test_vb_usermemid_requires_an_unquoted_integer(self) -> None:
        for value in ('"0"', "True", "SomeConstant"):
            with self.subTest(value=value):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Typed.cls",
                    f'''Attribute VB_Name = "Typed"
Public Property Get Item() As Variant
End Property
Attribute Item.VB_UserMemId = {value}
''',
                )
                with self.assertRaisesRegex(SurfaceError, "unquoted integer"):
                    fixture.extract([("ClassModule", "Typed.cls")])

        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Typed.cls",
            '''Attribute VB_Name = "Typed"
Public Property Get Item() As Variant
End Property
Attribute Item.VB_UserMemId = -0
''',
        )
        with self.assertRaisesRegex(SurfaceError, "signed zero"):
            fixture.extract([("ClassModule", "Typed.cls")])

    def test_member_attribute_must_not_use_physical_line_continuation(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Typed.cls",
            '''Attribute VB_Name = "Typed"
Public Property Get Item() As Variant
End Property
Attribute Item.VB_UserMemId = _
0
''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "member Attribute must occupy one physical source line"
        ):
            fixture.extract([("ClassModule", "Typed.cls")])

    def test_default_declaration_modifier_is_not_in_pinned_calcvba_grammar(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Typed.cls",
            '''Attribute VB_Name = "Typed"
Public Default Property Get Item() As Variant
End Property
''',
        )
        with self.assertRaisesRegex(
            SurfaceError, "unparsed externally visible declaration"
        ):
            fixture.extract([("ClassModule", "Typed.cls")])

    def test_global_variable_is_retained_as_explicit_public_surface(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Globals.bas",
            '''
            Attribute VB_Name = "Globals"
            Global SharedValue As Long
            Public UserForms As New UserForms
            ''',
        )
        surface = fixture.extract([("Module", "Globals.bas")])
        declaration = surface["modules"][0]["declarations"][0]
        self.assertEqual("variable", declaration["kind"])
        self.assertEqual("public", declaration["visibility"])
        self.assertEqual("global", declaration["visibility_keyword"])
        self.assertEqual("SharedValue", declaration["name"])
        self.assertFalse(declaration["as_new"])
        lazy = surface["modules"][0]["declarations"][1]
        self.assertEqual("UserForms", lazy["name"])
        self.assertEqual("UserForms", lazy["type"])
        self.assertTrue(lazy["as_new"])

    def test_source_boolean_metadata_overrides_preserved_basproj_metadata(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Published.cls",
            '''
            Attribute VB_Name = "Published"
            Attribute VB_Exposed = False
            Attribute VB_Creatable = False
            ''',
        )
        fixture.project.write_text(
            PROJECT_PREFIX
            + '''
              <ItemGroup>
                <ClassModule Include="Published.cls">
                  <VBPredeclaredId>True</VBPredeclaredId>
                  <VBExposed>True</VBExposed>
                  <VBGlobalNamespace>True</VBGlobalNamespace>
                  <VBCreatable>True</VBCreatable>
                  <Instancing>PublicNotCreatable</Instancing>
                  <ProgId>Fixture.Published</ProgId>
                  <Description>Published fixture</Description>
                </ClassModule>
              </ItemGroup>
            '''
            + PROJECT_SUFFIX,
            encoding="utf-8",
            newline="\n",
        )
        module = extract_surface(fixture.root, fixture.project)["modules"][0]
        self.assertEqual(
            {
                "Description": "Published fixture",
                "Instancing": "PublicNotCreatable",
                "ProgId": "Fixture.Published",
                "VBCreatable": True,
                "VBExposed": True,
                "VBGlobalNamespace": True,
                "VBPredeclaredId": True,
            },
            module["manifest_metadata"],
        )
        self.assertFalse(module["project_declared_exposed"])
        self.assertFalse(module["project_declared_creatable"])
        self.assertTrue(module["project_declared_predeclared_id"])
        self.assertTrue(module["project_declared_global_namespace"])

    def test_invalid_or_unknown_basproj_metadata_fails_closed(self) -> None:
        for metadata, expected in (
            ("<VBExposed>perhaps</VBExposed>", "must be True or False"),
            ("<Instancing>Surprise</Instancing>", "six recognized values"),
            ("<Surprise>True</Surprise>", "unsupported metadata"),
        ):
            with self.subTest(metadata=metadata):
                fixture = TemporaryVbaProject(self)
                fixture.source("Fixture.cls", 'Attribute VB_Name = "Fixture"\n')
                fixture.project.write_text(
                    PROJECT_PREFIX
                    + "<ItemGroup><ClassModule Include=\"Fixture.cls\">"
                    + metadata
                    + "</ClassModule></ItemGroup>"
                    + PROJECT_SUFFIX,
                    encoding="utf-8",
                    newline="\n",
                )
                with self.assertRaisesRegex(SurfaceError, expected):
                    extract_surface(fixture.root, fixture.project)

    def test_instancing_enum_header_precedence_and_surface_effects_are_exact(self) -> None:
        expectations = {
            "Private": (False, False),
            "PublicNotCreatable": (False, False),
            "MultiUse": (True, False),
            "SingleUse": (True, False),
            "GlobalMultiUse": (True, True),
            "GlobalSingleUse": (True, True),
        }
        for instancing, (creatable, global_namespace) in expectations.items():
            with self.subTest(instancing=instancing):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Instanced.cls",
                    '''Attribute VB_Name = "Instanced"
Attribute VB_Exposed = True
Attribute VB_Creatable = False
Attribute VB_GlobalNameSpace = False
''',
                )
                fixture.project.write_text(
                    PROJECT_PREFIX
                    + '<ItemGroup><ClassModule Include="Instanced.cls">'
                    + f"<Instancing>{instancing}</Instancing>"
                    + "</ClassModule></ItemGroup>"
                    + PROJECT_SUFFIX,
                    encoding="utf-8",
                    newline="\n",
                )
                module = extract_surface(fixture.root, fixture.project)["modules"][0]
                self.assertEqual(instancing, module["effective_instancing"])
                self.assertEqual(creatable, module["project_declared_creatable"])
                self.assertEqual(
                    global_namespace,
                    module["project_declared_global_namespace"],
                )

        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Header.cls",
            '''VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Header"
Attribute VB_Exposed = True
Attribute VB_Creatable = False
''',
        )
        header = fixture.extract([("ClassModule", "Header.cls")])["modules"][0]
        self.assertEqual("MultiUse", header["source_header_instancing"])
        self.assertEqual("MultiUse", header["effective_instancing"])
        self.assertTrue(header["project_declared_creatable"])

        fixture.project.write_text(
            PROJECT_PREFIX
            + '<ItemGroup><ClassModule Include="Header.cls">'
            + "<Instancing>PublicNotCreatable</Instancing>"
            + "</ClassModule></ItemGroup>"
            + PROJECT_SUFFIX,
            encoding="utf-8",
            newline="\n",
        )
        overridden = extract_surface(fixture.root, fixture.project)["modules"][0]
        self.assertEqual("MultiUse", overridden["source_header_instancing"])
        self.assertEqual("PublicNotCreatable", overridden["effective_instancing"])
        self.assertFalse(overridden["project_declared_creatable"])

    def test_invalid_or_ambiguous_class_header_instancing_fails_closed(self) -> None:
        for label, header in {
            "invalid": "  Instancing = 9",
            "wrong_case": "  Instancing = multiuse",
            "ambiguous": "  MultiUse = -1\n  SingleUse = -1",
        }.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Header.cls",
                    f'''VERSION 1.0 CLASS
BEGIN
{header}
END
Attribute VB_Name = "Header"
''',
                )
                with self.assertRaisesRegex(
                    SurfaceError, "unsupported exported|ambiguous exported"
                ):
                    fixture.extract([("ClassModule", "Header.cls")])

    def test_exported_class_header_terminator_must_be_raw_end(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Header.cls",
            '''VERSION 1.0 CLASS
BEGIN
  MultiUse = -1
END ' a comment makes this differ from CalcVBA's raw END terminator
Attribute VB_Name = "Header"
''',
        )
        with self.assertRaisesRegex(SurfaceError, "unterminated exported class header"):
            fixture.extract([("ClassModule", "Header.cls")])

    def test_vba_module_utf8_bom_is_rejected_before_normalization(self) -> None:
        for kind, filename in (
            ("Module", "Bom.bas"),
            ("ClassModule", "Bom.cls"),
        ):
            with self.subTest(kind=kind):
                fixture = TemporaryVbaProject(self)
                source_path = fixture.source(
                    filename, 'Attribute VB_Name = "Bom"\n'
                )
                source_path.write_bytes(b"\xef\xbb\xbf" + source_path.read_bytes())
                with self.assertRaisesRegex(
                    SurfaceError, "UTF-8 BOM is unsupported in VBA module"
                ):
                    fixture.extract([(kind, filename)])

    def test_vba_module_lone_cr_line_endings_are_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        source_path = fixture.source(
            "Header.cls",
            '''VERSION 1.0 CLASS
BEGIN
  MultiUse = -1
END
Attribute VB_Name = "Header"
''',
        )
        source_path.write_bytes(source_path.read_bytes().replace(b"\n", b"\r"))
        with self.assertRaisesRegex(
            SurfaceError, "lone CR line endings are unsupported"
        ):
            fixture.extract([("ClassModule", "Header.cls")])

    def test_exported_class_header_is_not_scanned_as_live_vba_body(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Header.cls",
            '''VERSION 1.0 CLASS
BEGIN
  MultiUse = -1
  Attribute VB_Exposed = True
  Public Sub HeaderGhost()
END
Attribute VB_Name = "Header"
Attribute VB_Exposed = False
Public Sub RealBodyMember()
End Sub
''',
        )
        module = fixture.extract([("ClassModule", "Header.cls")])["modules"][0]
        self.assertFalse(module["project_declared_exposed"])
        self.assertEqual(
            ["RealBodyMember"],
            [declaration["name"] for declaration in module["declarations"]],
        )
        self.assertEqual(9, module["declarations"][0]["source"]["start_line"])

    def test_conditional_or_item_shaping_basproj_inventory_is_rejected(self) -> None:
        cases = {
            "item_condition": (
                PROJECT_PREFIX
                + '<ItemGroup><Module Include="Conditional.bas" '
                'Condition="false" /></ItemGroup>'
                + PROJECT_SUFFIX,
                "conditional basproj",
            ),
            "group_condition": (
                PROJECT_PREFIX
                + '<ItemGroup Condition="false"><Module '
                'Include="Conditional.bas" /></ItemGroup>'
                + PROJECT_SUFFIX,
                "conditional basproj",
            ),
            "choose_branch": (
                PROJECT_PREFIX
                + '<Choose><When Condition="false"><ItemGroup><Module '
                'Include="Conditional.bas" /></ItemGroup></When></Choose>'
                + PROJECT_SUFFIX,
                "conditional basproj",
            ),
            "unreviewed_item_shape": (
                PROJECT_PREFIX
                + '<ItemGroup><Module Include="Conditional.bas" '
                'Remove="Other.bas" /></ItemGroup>'
                + PROJECT_SUFFIX,
                "unsupported attributes on Module",
            ),
        }
        for label, (manifest, expected) in cases.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source(
                    "Conditional.bas", 'Attribute VB_Name = "Conditional"\n'
                )
                fixture.project.write_text(
                    manifest, encoding="utf-8", newline="\n"
                )
                with self.assertRaisesRegex(SurfaceError, expected):
                    extract_surface(fixture.root, fixture.project)

    def test_clean_project_sdk_and_library_identity_are_exact(self) -> None:
        mutations = {
            "missing_sdk": PROJECT_PREFIX.replace(
                ' Sdk="CalcVBA.Sdk/0.1.0"', ""
            ),
            "wrong_sdk": PROJECT_PREFIX.replace("0.1.0", "9.9.9"),
            "wrong_output": PROJECT_PREFIX.replace(
                "<OutputType>Library</OutputType>",
                "<OutputType>Exe</OutputType>",
            ),
            "wrong_name": PROJECT_PREFIX.replace(
                "<ProjectName>CalcForms</ProjectName>",
                "<ProjectName>Other</ProjectName>",
            ),
            "duplicate_properties": PROJECT_PREFIX.replace(
                "  </PropertyGroup>",
                "  </PropertyGroup><PropertyGroup><ProjectName>CalcForms</ProjectName></PropertyGroup>",
            ),
        }
        for label, prefix in mutations.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source("Fixture.bas", 'Attribute VB_Name = "Fixture"\n')
                fixture.project.write_text(
                    prefix
                    + '<ItemGroup><Module Include="Fixture.bas" /></ItemGroup>'
                    + PROJECT_SUFFIX,
                    encoding="utf-8",
                    newline="\n",
                )
                with self.assertRaisesRegex(
                    SurfaceError,
                    "Project identity|exactly one PropertyGroup|OutputType=Library",
                ):
                    extract_surface(fixture.root, fixture.project)

    def test_basproj_xml_normalizations_not_shared_by_calcvba_are_rejected(self) -> None:
        mutations = {
            "sdk_character_reference": PROJECT_PREFIX.replace(
                "CalcVBA.Sdk/0.1.0", "CalcVBA.Sdk/&#48;.1.0"
            )
            + '<ItemGroup><Module Include="Fixture.bas" /></ItemGroup>'
            + PROJECT_SUFFIX,
            "include_character_reference": PROJECT_PREFIX
            + '<ItemGroup><Module Include="&#70;ixture.bas" /></ItemGroup>'
            + PROJECT_SUFFIX,
            "cdata_property": PROJECT_PREFIX.replace(
                "<OutputType>Library</OutputType>",
                "<OutputType><![CDATA[Library]]></OutputType>",
            )
            + '<ItemGroup><Module Include="Fixture.bas" /></ItemGroup>'
            + PROJECT_SUFFIX,
            "doctype_entity": PROJECT_PREFIX.replace(
                '<Project Sdk="CalcVBA.Sdk/0.1.0">',
                '<!DOCTYPE Project [<!ENTITY sdk "CalcVBA.Sdk/0.1.0">]>\n'
                '<Project Sdk="&sdk;">',
            )
            + '<ItemGroup><Module Include="Fixture.bas" /></ItemGroup>'
            + PROJECT_SUFFIX,
        }
        for label, manifest in mutations.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source("Fixture.bas", 'Attribute VB_Name = "Fixture"\n')
                fixture.project.write_text(manifest, encoding="utf-8", newline="\n")
                with self.assertRaisesRegex(
                    SurfaceError, "unsupported in exact basproj"
                ):
                    extract_surface(fixture.root, fixture.project)

    def test_namespaced_basproj_children_are_not_treated_as_exact_items(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source("Fixture.bas", 'Attribute VB_Name = "Fixture"\n')
        fixture.project.write_text(
            '''<Project Sdk="CalcVBA.Sdk/0.1.0" xmlns:x="urn:not-oxvba">
  <x:PropertyGroup>
    <x:OutputType>Library</x:OutputType>
    <x:ProjectName>CalcForms</x:ProjectName>
  </x:PropertyGroup>
  <x:ItemGroup><x:Module Include="Fixture.bas" /></x:ItemGroup>
</Project>
''',
            encoding="utf-8",
            newline="\n",
        )
        with self.assertRaisesRegex(SurfaceError, "XML namespaces are unsupported"):
            extract_surface(fixture.root, fixture.project)

    def test_nonwhitespace_basproj_container_text_and_tails_are_rejected(self) -> None:
        for label, manifest in {
            "project_text": PROJECT_PREFIX.replace(
                '<Project Sdk="CalcVBA.Sdk/0.1.0">',
                '<Project Sdk="CalcVBA.Sdk/0.1.0">garbage',
            )
            + '<ItemGroup><Module Include="Fixture.bas" /></ItemGroup>'
            + PROJECT_SUFFIX,
            "item_text": PROJECT_PREFIX
            + '<ItemGroup>garbage<Module Include="Fixture.bas" />tail</ItemGroup>'
            + PROJECT_SUFFIX,
        }.items():
            with self.subTest(label=label):
                fixture = TemporaryVbaProject(self)
                fixture.source("Fixture.bas", 'Attribute VB_Name = "Fixture"\n')
                fixture.project.write_text(
                    manifest, encoding="utf-8", newline="\n"
                )
                with self.assertRaisesRegex(
                    SurfaceError, "non-whitespace .* exact basproj"
                ):
                    extract_surface(fixture.root, fixture.project)

    def test_private_interface_member_uses_longest_declared_underscore_prefix(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source(
            "Implementation.cls",
            '''
            Attribute VB_Name = "Implementation"
            Implements IFoo
            Implements IFoo_Bar

            Private Sub IFoo_Bar_DoThing(ByVal Value As Long)
            End Sub
            ''',
        )
        module = fixture.extract([("ClassModule", "Implementation.cls")])["modules"][0]
        implementation = module["interface_implementations"][0]
        self.assertEqual("IFoo_Bar", implementation["interface"])
        self.assertEqual("DoThing", implementation["interface_member"])

    def test_duplicate_basproj_include_is_case_insensitively_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source("One.bas", 'Attribute VB_Name = "One"\n')
        with self.assertRaisesRegex(SurfaceError, "duplicate basproj Include"):
            fixture.extract([("Module", "One.bas"), ("Module", "ONE.BAS")])

    def test_duplicate_declared_module_name_is_case_insensitively_rejected(self) -> None:
        fixture = TemporaryVbaProject(self)
        fixture.source("One.bas", 'Attribute VB_Name = "Shared"\n')
        fixture.source("Two.bas", 'Attribute VB_Name = "shared"\n')
        with self.assertRaisesRegex(SurfaceError, "duplicate VBA module name"):
            fixture.extract([("Module", "One.bas"), ("Module", "Two.bas")])

    def test_lf_and_crlf_have_identical_semantic_surface_identity(self) -> None:
        fixture = TemporaryVbaProject(self)
        source_path = fixture.source(
            "Fixture.cls",
            '''
            Attribute VB_Name = "Fixture"
            Attribute VB_Exposed = True
            Public Property Get Value() As Currency
            End Property
            ''',
        )
        manifest_path = fixture.manifest([("ClassModule", "Fixture.cls")])
        lf_surface = extract_surface(fixture.root, manifest_path)

        source_path.write_bytes(source_path.read_bytes().replace(b"\n", b"\r\n"))
        manifest_path.write_bytes(
            manifest_path.read_bytes().replace(b"\n", b"\r\n")
        )
        crlf_surface = extract_surface(fixture.root, manifest_path)

        self.assertEqual(lf_surface, crlf_surface)


class CurrentCalcFormsSurfaceCensusTests(unittest.TestCase):
    def test_current_basproj_census_is_exact_and_ordered(self) -> None:
        surface = extract_surface(
            REPO_ROOT, REPO_ROOT / "vba" / "calcforms" / "CalcForms.basproj"
        )
        self.assertEqual(CURRENT_MODULE_NAMES, [row["name"] for row in surface["modules"]])
        self.assertEqual(
            {
                "modules": 37,
                "class_modules": 33,
                "standard_modules": 4,
                "project_declared_exposed_modules": 5,
                "public_declarations": 832,
                "public_events": 114,
                "public_enum_constants": 25,
                "public_type_fields": 9,
                "multiline_public_signatures": 36,
                "bracketed_public_names": 11,
                "optional_parameters": 2,
                "param_arrays": 1,
                "module_attributes": 5,
                "implements_clauses": 23,
                "private_interface_implementations": 541,
                "member_attributes": 0,
            },
            surface["summary"],
        )
        self.assertEqual(
            "69ea3038eae07cf36cb56a8337d4c948ba8f8d6e37dbcb6b7ccbee660464d56d",
            surface["canonical_sha256"],
        )
        by_name = {module["name"]: module for module in surface["modules"]}
        smoke = by_name["CalcFormsSmokeForm"]
        self.assertEqual("MultiUse", smoke["source_header_instancing"])
        self.assertEqual("MultiUse", smoke["effective_instancing"])
        self.assertTrue(smoke["project_declared_creatable"])
        self.assertTrue(
            all(
                module["project_declared_global_namespace"]
                for module in surface["modules"]
                if module["kind"] == "standard_module"
            )
        )


if __name__ == "__main__":
    unittest.main()
