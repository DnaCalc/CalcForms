//! Office UserForm ingestion. Office containers and source extraction belong to
//! calcvba-office; this module decodes the selected MS-OFORMS control graph.
//! Behavior and rendering remain in the VBA library, including original handlers.
//!
//! Supported persistence: flat Label, CommandButton, TextBox and CheckBox forms.
//! Unsupported classes, nested sites, picture streams and external data bindings
//! are errors, rather than controls silently disappearing from a loaded form.
//! Binary layouts: public MS-OFORMS §§2.2.1, 2.2.4, 2.2.5, 2.2.10–2.2.12.

use std::collections::BTreeMap;
use std::io::{Cursor, Read};
use std::path::Path;
use std::sync::Arc;

use crate::host_services::HostServices;
use crate::runtime::OxRuntime;
use crate::surface::{register_surface, SharedShaper, SurfaceFactory};
use calcvba_office::{ModuleKind, OfficeFile};
use calcvba_symbol::manifest::{ModuleAttributes, ModuleUnit};

type Result<T> = std::result::Result<T, String>;
const MAX_STREAM: usize = 4 * 1024 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ControlKind {
    Label,
    CommandButton,
    TextBox,
    CheckBox,
}

impl ControlKind {
    pub fn class_name(self) -> &'static str {
        match self {
            Self::Label => "Label",
            Self::CommandButton => "CommandButton",
            Self::TextBox => "TextBox",
            Self::CheckBox => "CheckBox",
        }
    }
}

#[derive(Clone, Debug)]
pub struct PersistedControl {
    pub name: String,
    pub kind: ControlKind,
    pub left: f64,
    pub top: f64,
    pub width: f64,
    pub height: f64,
    pub caption: String,
    pub value: String,
    pub visible: bool,
    pub enabled: bool,
    pub tab_stop: bool,
    pub tab_index: i16,
    pub default_button: bool,
    pub cancel_button: bool,
    pub word_wrap: bool,
    pub font_name: String,
    pub font_size: f64,
}

#[derive(Clone, Debug)]
pub struct WorkbookForm {
    pub name: String,
    pub caption: String,
    /// The client area, in MSForms points. The OS supplies the window frame.
    pub width: f64,
    pub height: f64,
    pub controls: Vec<PersistedControl>,
    pub original_source: String,
    /// Self-contained standard modules from the same Office project.
    pub project_modules: Vec<ModuleUnit>,
}

impl WorkbookForm {
    /// The current host registers one face per form. Reject mixed faces instead
    /// of silently drawing accepted persisted names with the wrong face.
    pub fn font_name(&self) -> Result<&str> {
        let name = self
            .controls
            .first()
            .map_or("Tahoma", |c| c.font_name.as_str());
        if self
            .controls
            .iter()
            .any(|c| !c.font_name.eq_ignore_ascii_case(name))
        {
            return Err("mixed font faces are not supported by this form host".into());
        }
        Ok(name)
    }
    /// Compile the selected form with the embedded VBA library and initialize it
    /// on VM3. Window creation belongs to the host; the returned Scene can also
    /// be inspected and rendered without a desktop.
    pub fn runtime(
        &self,
        shaper: SharedShaper,
        host_services: HostServices,
    ) -> Result<(OxRuntime, Arc<SurfaceFactory>)> {
        self.runtime_with_entry(shaper, host_services, None)
    }

    /// Run an original, parameterless workbook entry before attaching its default form.
    pub fn runtime_with_entry(
        &self,
        shaper: SharedShaper,
        host_services: HostServices,
        entry: Option<&str>,
    ) -> Result<(OxRuntime, Arc<SurfaceFactory>)> {
        let library: Vec<_> = crate::library::modules()
            .into_iter()
            .map(|mut module| {
                // The referenced library exposes its current class surface to the
                // form source provider. W010 still owns narrowing its public API.
                if module.module_kind == calcvba_symbol::manifest::ModuleKind::Class {
                    module.attributes.vb_exposed = true;
                    module.attributes.vb_creatable =
                        matches!(module.module_name.as_str(), "UserForm" | "OxReducer");
                }
                module
            })
            .collect();
        if library
            .iter()
            .any(|module| module.module_name.eq_ignore_ascii_case(&self.name))
        {
            return Err(format!(
                "form name {:?} collides with a library module",
                self.name
            ));
        }
        let mut modules = vec![self.module()?];
        if modules.iter().any(|module| {
            [
                "CalcFormsWorkbookHost",
                "CalcFormsWorkbookLifetime",
                "ICalcFormsLifecycle",
            ]
            .iter()
            .any(|reserved| module.module_name.eq_ignore_ascii_case(reserved))
        }) {
            return Err("workbook uses a reserved host module name".into());
        }
        for module in &self.project_modules {
            if [
                "CalcFormsWorkbookHost",
                "CalcFormsWorkbookLifetime",
                "ICalcFormsLifecycle",
            ]
            .iter()
            .any(|reserved| module.module_name.eq_ignore_ascii_case(reserved))
            {
                return Err("workbook uses a reserved host module name".into());
            }
            if modules
                .iter()
                .any(|m| m.module_name.eq_ignore_ascii_case(&module.module_name))
            {
                return Err(format!(
                    "workbook module name collision: {}",
                    module.module_name
                ));
            }
            modules.push(module.clone());
        }
        let entry = entry
            .map(|name| {
                if !name.split('.').all(valid_name) || name.split('.').count() > 2 {
                    return Err("invalid workbook entry procedure".to_string());
                }
                Ok(format!("    Call {name}\n"))
            })
            .transpose()?
            .unwrap_or_default();
        modules.push(ModuleUnit {
            module_name: "CalcFormsWorkbookHost".into(),
            module_kind: calcvba_symbol::manifest::ModuleKind::Class,
            attributes: ModuleAttributes::named("CalcFormsWorkbookHost"),
            source: format!("Option Explicit\nPrivate Sub Start()\n{entry}End Sub\nPrivate Function DefaultForm() As {}\n    Set DefaultForm = {}\nEnd Function\n", self.name, self.name),
        });
        modules.push(ModuleUnit {
            module_name: "CalcFormsWorkbookLifetime".into(),
            module_kind: calcvba_symbol::manifest::ModuleKind::Procedural,
            attributes: ModuleAttributes::named("CalcFormsWorkbookLifetime"),
            source: include_str!("../../../vba/calcforms/runtime/WorkbookLifetime.vba").into(),
        });
        modules.push(ModuleUnit {
            module_name: "ICalcFormsLifecycle".into(),
            module_kind: calcvba_symbol::manifest::ModuleKind::Class,
            attributes: ModuleAttributes::named("ICalcFormsLifecycle"),
            source: include_str!("../../../vba/calcforms/runtime/ICalcFormsLifecycle.vba").into(),
        });
        let manifest = calcvba_symbol::manifest::SymbolProjectManifest {
            project_name: "CalcFormsWorkbook".into(),
            project_kind: calcvba_symbol::manifest::ProjectKind::Library,
            modules,
            references: vec![calcvba_symbol::manifest::ProjectReference::Project {
                referenced_project_name: "MSForms".into(),
            }],
            reference_projects: vec![calcvba_symbol::manifest::ReferencedProjectManifest {
                project_name: "MSForms".into(),
                project_kind: calcvba_symbol::manifest::ProjectKind::Library,
                modules: library.clone(),
            }],
            conditional_constants: Default::default(),
            conditional_compilation_target: Default::default(),
        };
        let library_manifest = calcvba_symbol::manifest::SymbolProjectManifest {
            project_name: "MSForms".into(),
            project_kind: calcvba_symbol::manifest::ProjectKind::Library,
            modules: library,
            references: vec![],
            reference_projects: vec![],
            conditional_constants: Default::default(),
            conditional_compilation_target: Default::default(),
        };
        // Project event ids include private events in compiler source order.
        // Resolve the generated capability by symbol identity: an application
        // event with the same string payload must never reset the default slot.
        let environment = calcvba_symbol::build_resolution_environment(
            &manifest,
            &calcvba_symbol::CatalogTypeLibResolver,
        )
        .map_err(|error| format!("resolve UserForm lifecycle event: {error}"))?;
        let form_scope = environment
            .modules()
            .find(|module| module.module_name.eq_ignore_ascii_case(&self.name))
            .ok_or("missing UserForm module scope")?
            .module_scope;
        let unload_name = environment
            .symbols
            .lookup_name("CalcFormsHostUnloading")
            .ok_or("missing UserForm lifecycle event symbol")?;
        let unload_event_id = environment
            .symbols
            .symbols()
            .iter()
            .filter(|symbol| {
                symbol.scope == form_scope && symbol.kind == calcvba_symbol::SymbolKind::Event
            })
            .position(|symbol| symbol.name == unload_name)
            .ok_or("missing UserForm lifecycle event ordinal")?
            as i32;
        let programs = calcvba_bind::bind_projects(
            &[library_manifest, manifest],
            &calcvba_symbol::CatalogTypeLibResolver,
        )
        .map_err(|error| format!("bind UserForm project: {error}"))?;
        let bundles = programs
            .iter()
            .map(calcvba_oxir::elaborate::elaborate)
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(|error| format!("compile UserForm project: {error}"))?;
        let projection = Arc::new(calcvba_com::PortableComProjection::new());
        let surface = Arc::new(SurfaceFactory::with_shaper(shaper));
        register_surface(&projection, surface.clone());
        let profile = calcvba_engine::HostProfileProvider::new()
            .with_portable_com_projection(projection)
            .with_host_policy(calcvba_hal::model::HostPolicy::native());
        let engine = calcvba_engine::Engine::new(calcvba_engine::HostConfig::vm3())
            .with_host_profile_provider(profile);
        let mut session = engine
            .prepare_image_session(calcvba_oxir::OxImage::new(bundles))
            .map_err(|error| format!("prepare UserForm VM3: {error}"))?;
        // This same-thread callback can clear the exact compiler-owned slot
        // without resolving (and accidentally constructing) its default object.
        let defaults = session.default_instances();
        let form_class = format!("CalcFormsWorkbook.{}", self.name);
        let form_name = self.name.clone();
        session.set_project_event_sink(move |owner, event_id, arguments| {
            let owned_form = owner.try_class_descriptor().is_some_and(|descriptor| {
                descriptor.name.eq_ignore_ascii_case(&form_name)
                    && descriptor.project_identity.is_some_and(|identity| {
                        identity.unit_name.eq_ignore_ascii_case("CalcFormsWorkbook")
                    })
            });
            if event_id == unload_event_id
                && owned_form
                && arguments.len() == 1
                && arguments[0]
                    .as_bstr()
                    .is_some_and(|name| name.as_str() == form_class)
            {
                defaults
                    .reset_if_same(&form_class, &owner)
                    .map_err(|error| error.to_string())?;
            }
            Ok(())
        });
        let host = session
            .create_class_instance("CalcFormsWorkbookHost")
            .map_err(|error| format!("create workbook host: {}", error.message()))?;
        session
            .invoke_member_values(
                host.clone(),
                "Start",
                Some(calcvba_bundle::ProjectMemberKind::Method),
                vec![],
            )
            .map_err(|error| format!("workbook entry: {}", error.message()))?;
        let mut runtime = OxRuntime::attach_default(session, host, host_services)?
            .with_member_prefix("CalcFormsHost");
        runtime.render()?;
        Ok((runtime, surface))
    }
    /// Load a selected, self-contained UserForm from an actual Office workbook.
    /// Nothing in this path starts Office or executes the workbook's entry macros.
    pub fn open(path: impl AsRef<Path>, form_name: &str) -> Result<Self> {
        let office =
            OfficeFile::open(path).map_err(|error| format!("read Office project: {error}"))?;
        let module = office
            .project
            .modules
            .iter()
            .find(|module| {
                module.kind == ModuleKind::Form && module.name.eq_ignore_ascii_case(form_name)
            })
            .ok_or_else(|| format!("workbook has no UserForm {form_name:?}"))?;
        // The Office crate currently exposes resources through its canonical
        // source-folder export. Keep this private and remove it on return.
        let temporary = tempfile::tempdir().map_err(|error| error.to_string())?;
        let folder = temporary.path().join("project");
        office
            .project
            .export_folder(&folder)
            .map_err(|error| format!("export Office source: {error}"))?;
        let frm = std::fs::read_to_string(folder.join(format!("{}.frm", module.name)))
            .map_err(|error| error.to_string())?;
        let frx = std::fs::read(folder.join(format!("{}.frx", module.name)))
            .map_err(|error| error.to_string())?;
        let mut form = Self::from_export(&module.name, &module.source, &frm, &frx)?;
        form.project_modules = office
            .project
            .modules
            .iter()
            .filter(|module| module.kind == ModuleKind::Standard)
            .map(|module| ModuleUnit {
                module_name: module.name.clone(),
                module_kind: calcvba_symbol::manifest::ModuleKind::Procedural,
                attributes: ModuleAttributes::named(&module.name),
                source: module
                    .source
                    .lines()
                    .filter(|line| !line.trim_start().starts_with("Attribute VB_"))
                    .collect::<Vec<_>>()
                    .join("\n"),
            })
            .collect();
        Ok(form)
    }

    fn from_export(name: &str, source: &str, frm: &str, frx: &[u8]) -> Result<Self> {
        if !valid_name(name) {
            return Err("invalid VBA form name".into());
        }
        let resource = frm
            .lines()
            .find(|line| line.trim_start().starts_with("OleObjectBlob"))
            .ok_or("form has no OleObjectBlob")?;
        if !resource.trim_end().ends_with(":0000") {
            return Err("nonzero OleObjectBlob offsets are not supported".into());
        }
        if frx.len() < 24
            || &frx[..4] != b"LB\x08\0"
            || u32::from_le_bytes(frx[4..8].try_into().map_err(|_| "resource length")?) as usize
                != frx.len() - 24
        {
            return Err("invalid VBE form resource header".into());
        }
        let mut compound = cfb::CompoundFile::open(Cursor::new(&frx[24..]))
            .map_err(|error| format!("form compound storage: {error}"))?;
        let mut stream = |name: &str| -> Result<Vec<u8>> {
            let mut bytes = Vec::new();
            compound
                .open_stream(name)
                .map_err(|error| format!("form stream {name}: {error}"))?
                .take(MAX_STREAM as u64 + 1)
                .read_to_end(&mut bytes)
                .map_err(|error| error.to_string())?;
            if bytes.len() > MAX_STREAM {
                return Err(format!("form stream {name} exceeds size limit"));
            }
            Ok(bytes)
        };
        let form = stream("/f")?;
        let objects = stream("/o")?;
        let controls = decode_form(&form, &objects)?;
        let caption = frm
            .lines()
            .find_map(|line| {
                let (key, value) = line.trim().split_once('=')?;
                (key.trim() == "Caption")
                    .then(|| value.trim().trim_matches('"').replace("\"\"", "\""))
            })
            .unwrap_or_else(|| name.into());
        let dimension = |key: &str| -> Result<f64> {
            let value = frm
                .lines()
                .find_map(|line| {
                    let (name, value) = line.trim().split_once('=')?;
                    (name.trim() == key).then_some(value.trim())
                })
                .ok_or_else(|| format!("form is missing {key}"))?;
            let twips = value.parse::<f64>().map_err(|_| format!("invalid {key}"))?;
            if !twips.is_finite() || twips <= 0.0 || twips > 200_000.0 {
                return Err(format!("unsupported {key} {twips}"));
            }
            Ok(twips / 20.0)
        };
        Ok(Self {
            name: name.into(),
            caption,
            width: dimension("ClientWidth")?,
            height: dimension("ClientHeight")?,
            controls,
            original_source: source.into(),
            project_modules: vec![],
        })
    }

    /// Compose host-owned private entrypoints and persisted control fields with
    /// the original form's declarations and procedure bodies. The VBA compiler
    /// binds the ordinary Name_Event handlers to the actual WithEvents controls.
    pub fn module(&self) -> Result<ModuleUnit> {
        self.font_name()?;
        if self
            .original_source
            .to_ascii_lowercase()
            .contains("calcformshost")
        {
            return Err("form source uses the reserved CalcFormsHost member prefix".into());
        }
        let source = self.original_source.replace("\r\n", "\n");
        let lines: Vec<_> = source
            .lines()
            .filter(|line| !line.trim_start().starts_with("Attribute VB_"))
            .collect();
        let procedure = lines
            .iter()
            .position(|line| {
                let tokens: Vec<_> = line.split_whitespace().take(3).collect();
                tokens.iter().take(2).any(|word| {
                    ["Sub", "Function", "Property"]
                        .iter()
                        .any(|kind| word.eq_ignore_ascii_case(kind))
                })
            })
            .unwrap_or(lines.len());
        let declarations = lines[..procedure].join("\n");
        let procedures = lines[procedure..].join("\n");
        let mut members = String::from("Implements ICalcFormsLifecycle\nPrivate Event CalcFormsHostUnloading(ByVal FormClass As String)\n");
        let mut build = format!("    Set CalcFormsHostForm = New UserForm\n    CalcFormsHostForm.Name = {}\n    CalcFormsHostForm.Caption = {}\n    CalcFormsHostForm.Width = {}\n    CalcFormsHostForm.Height = {}\n", literal(&self.name), literal(&self.caption), self.width, self.height);
        for control in &self.controls {
            let name = &control.name;
            let class = control.kind.class_name();
            members.push_str(&format!("Public WithEvents {name} As {class}\n"));
            build.push_str(&format!(
                "    Set {name} = CalcFormsHostForm.Controls.Add(\"Forms.{class}.1\", {})\n",
                literal(name)
            ));
            for (property, value) in [
                ("Left", control.left),
                ("Top", control.top),
                ("Width", control.width),
                ("Height", control.height),
            ] {
                build.push_str(&format!("    {name}.{property} = {value}\n"));
            }
            for (property, value) in [
                ("Visible", control.visible),
                ("Enabled", control.enabled),
                ("TabStop", control.tab_stop),
            ] {
                build.push_str(&format!(
                    "    {name}.Core.{property} = {}\n",
                    boolean(value)
                ));
            }
            build.push_str(&format!(
                "    {name}.Core.TabIndex = {}\n    {name}.Core.FontSize = {}\n",
                control.tab_index, control.font_size
            ));
            match control.kind {
                ControlKind::TextBox => {
                    build.push_str(&format!("    {name}.Text = {}\n", literal(&control.value)))
                }
                ControlKind::CheckBox => {
                    if !["", "0", "1"].contains(&control.value.as_str()) {
                        return Err(format!("three-state CheckBox {name} is not supported"));
                    }
                    build.push_str(&format!(
                        "    {name}.Caption = {}\n    {name}.Value = {}\n",
                        literal(&control.caption),
                        boolean(control.value == "1")
                    ));
                }
                ControlKind::Label => build.push_str(&format!(
                    "    {name}.Caption = {}\n    {name}.WordWrap = {}\n",
                    literal(&control.caption),
                    boolean(control.word_wrap)
                )),
                ControlKind::CommandButton => build.push_str(&format!(
                    "    {name}.Caption = {}\n    {name}.Default = {}\n    {name}.Cancel = {}\n",
                    literal(&control.caption),
                    boolean(control.default_button),
                    boolean(control.cancel_button)
                )),
            }
        }
        build.push_str("    Set CalcFormsHostReducer = New OxReducer\n    CalcFormsHostReducer.Init CalcFormsHostForm\n");
        let mut host = include_str!("../../../vba/calcforms/runtime/WorkbookFormHost.vba")
            .replace(
                "Private CalcFormsHostForm As UserForm",
                "Private WithEvents CalcFormsHostForm As UserForm\nPrivate Sub CalcFormsHostForm_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)\n%MOUSEDOWN%\nEnd Sub",
            )
            .replace("%BUILD%", &build);
        for (token, name) in [
            ("INITIALIZE", "Initialize"),
            ("ACTIVATE", "Activate"),
            ("DEACTIVATE", "Deactivate"),
            ("TERMINATE", "Terminate"),
            ("QUERY_CLOSE", "QueryClose"),
            ("MOUSEDOWN", "MouseDown"),
        ] {
            let handler = format!("UserForm_{name}");
            let exists = procedures.lines().any(|line| {
                line.split_whitespace().any(|word| {
                    word.split('(')
                        .next()
                        .is_some_and(|word| word.eq_ignore_ascii_case(&handler))
                })
            });
            let call = if !exists {
                String::new()
            } else if name == "QueryClose" {
                format!("    {handler} Cancel, CloseMode")
            } else if name == "MouseDown" {
                format!("    {handler} Button, Shift, X, Y")
            } else {
                format!("    {handler}")
            };
            let call = match name {
                "Activate" => format!("    If CalcFormsHostActive Then Exit Sub\n    CalcFormsHostActive = True\n{call}"),
                "Deactivate" => format!("    If Not CalcFormsHostActive Then Exit Sub\n    CalcFormsHostActive = False\n{call}"),
                _ => call,
            };
            host = host.replace(&format!("%{token}%"), &call);
        }
        let input = self
            .controls
            .iter()
            .find(|control| control.kind == ControlKind::TextBox)
            .map(|control| format!("{}.Text", control.name))
            .unwrap_or_else(|| "\"\"".into());
        host = host.replace("%INPUT%", &input);
        host.push_str(
            &include_str!("../../../vba/calcforms/runtime/WorkbookFormLifetime.vba")
                .replace("%FORM_NAME%", &self.name),
        );
        let mut attributes = ModuleAttributes::named(&self.name);
        attributes.vb_predeclared_id = true;
        // CalcVBA currently persists FormModule items but does not emit their
        // classes. Designer fields and the VBA base implementation belong to
        // this source provider; procedure bodies remain application source.
        Ok(ModuleUnit {
            module_name: self.name.clone(),
            module_kind: calcvba_symbol::manifest::ModuleKind::Class,
            attributes,
            source: format!("{declarations}\n{members}\n{host}\n{procedures}\n"),
        })
    }
}

fn boolean(value: bool) -> &'static str {
    if value {
        "True"
    } else {
        "False"
    }
}
fn literal(value: &str) -> String {
    format!(
        "\"{}\"",
        value
            .replace('"', "\"\"")
            .replace('\r', "\" & vbCr & \"")
            .replace('\n', "\" & vbLf & \"")
            .replace('\0', "\" & Chr$(0) & \"")
    )
}

fn valid_name(name: &str) -> bool {
    let mut bytes = name.bytes();
    bytes
        .next()
        .is_some_and(|value| value.is_ascii_alphabetic())
        && bytes.all(|value| value.is_ascii_alphanumeric() || value == b'_')
}

struct Bytes<'a> {
    bytes: &'a [u8],
    pos: usize,
}
impl<'a> Bytes<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, pos: 0 }
    }
    fn take(&mut self, length: usize) -> Result<&'a [u8]> {
        let end = self.pos.checked_add(length).ok_or("form offset overflow")?;
        let value = self
            .bytes
            .get(self.pos..end)
            .ok_or_else(|| format!("truncated MS-OFORMS data at {}", self.pos))?;
        self.pos = end;
        Ok(value)
    }
    fn align(&mut self, width: usize) -> Result<()> {
        self.take((width - self.pos % width) % width).map(|_| ())
    }
    fn number(&mut self, width: usize) -> Result<u32> {
        self.align(width)?;
        let mut value = [0; 4];
        value[..width].copy_from_slice(self.take(width)?);
        Ok(u32::from_le_bytes(value))
    }
    fn string(&mut self, count: u32) -> Result<String> {
        let data = self.take((count & 0x7fff_ffff) as usize)?;
        let units: Vec<u16> = if count & 0x8000_0000 != 0 {
            // Compressed fmString stores the low byte of each UTF-16 unit;
            // it is not text in the VBA project's legacy codepage.
            data.iter().map(|value| u16::from(*value)).collect()
        } else {
            if data.len() % 2 != 0 {
                return Err("odd UTF-16 string length".into());
            }
            data.chunks_exact(2)
                .map(|unit| u16::from_le_bytes([unit[0], unit[1]]))
                .collect()
        };
        self.align(4)?;
        String::from_utf16(&units)
            .map_err(|_| "unpaired UTF-16 in persisted property is not supported".into())
    }
}

/// Each record bounds its own data and aligns fields relative to its start.
fn record(bytes: &[u8], version: u16, wide_mask: bool) -> Result<(Bytes<'_>, u64, usize)> {
    let mut header = Bytes::new(bytes);
    if header.number(2)? != u32::from(version) {
        return Err("unsupported MS-OFORMS record version".into());
    }
    let size = header.number(2)? as usize + 4;
    let mut data = Bytes::new(bytes.get(..size).ok_or("truncated MS-OFORMS record")?);
    data.pos = 4;
    let low = u64::from(data.number(4)?);
    let mask = if wide_mask {
        low | (u64::from(data.number(4)?) << 32)
    } else {
        low
    };
    Ok((data, mask, size))
}

fn fields(data: &mut Bytes<'_>, mask: u64, layout: &[(u8, usize)]) -> Result<BTreeMap<u8, u32>> {
    let mut values = BTreeMap::new();
    let known = layout
        .iter()
        .fold(0u64, |value, (bit, _)| value | (1u64 << bit));
    if mask & !known != 0 {
        return Err(format!(
            "unsupported MS-OFORMS property mask {:#x}",
            mask & !known
        ));
    }
    for &(bit, width) in layout {
        if mask & (1u64 << bit) != 0 && width != 0 {
            values.insert(bit, data.number(width)?);
        }
    }
    data.align(4)?;
    Ok(values)
}

fn decode_form(form: &[u8], objects: &[u8]) -> Result<Vec<PersistedControl>> {
    let (mut data, mask, end) = record(form, 0x0400, false)?;
    let properties = fields(
        &mut data,
        mask,
        &[
            (1, 4),
            (2, 4),
            (3, 4),
            (6, 4),
            (7, 1),
            (8, 1),
            (9, 1),
            (10, 0),
            (11, 0),
            (12, 0),
            (13, 4),
            (14, 0),
            (15, 2),
            (16, 1),
            (17, 1),
            (18, 4),
            (19, 4),
            (20, 2),
            (21, 2),
            (22, 4),
            (23, 1),
            (24, 0),
            (25, 1),
            (26, 4),
            (27, 4),
        ],
    )?;
    if mask & ((1 << 15) | (1 << 20) | (1 << 21)) != 0 {
        return Err("form font/picture stream properties are not supported".into());
    }
    for bit in [10, 11, 12] {
        if mask & (1 << bit) != 0 {
            data.take(8)?;
        }
    }
    if let Some(count) = properties.get(&19) {
        data.string(*count)?;
    }
    if data.pos != end {
        return Err("form record has unconsumed property data".into());
    }
    let mut sites = Bytes::new(&form[end..]);
    if properties.get(&6).copied().unwrap_or(4) & (1 << 15) == 0 && sites.number(2)? != 0 {
        return Err("custom ActiveX class tables are not supported".into());
    }
    // These fields are packed immediately after a possible 2-byte class count.
    let count = u32::from_le_bytes(sites.take(4)?.try_into().map_err(|_| "site count")?) as usize;
    let size = u32::from_le_bytes(sites.take(4)?.try_into().map_err(|_| "site size")?) as usize;
    if count > 2048 {
        return Err("form has too many control sites".into());
    }
    let mut array = Bytes::new(sites.take(size)?);
    let mut depths = 0usize;
    while depths < count {
        let depth = array.number(1)?;
        let kind = array.number(1)?;
        let run = if kind & 0x80 != 0 {
            if array.number(1)? != 1 {
                return Err("unsupported site type".into());
            }
            (kind & 0x7f) as usize
        } else {
            if kind != 1 {
                return Err("unsupported site type".into());
            }
            1
        };
        if depth != 0 || run == 0 {
            return Err("nested control sites are not supported".into());
        }
        depths += run;
    }
    if depths != count {
        return Err("site depth count differs from control count".into());
    }
    array.align(4)?;
    let mut output = Vec::with_capacity(count);
    let mut object_pos = 0usize;
    for _ in 0..count {
        let (mut site, mask, length) = record(&array.bytes[array.pos..], 0, false)?;
        let values = fields(
            &mut site,
            mask,
            &[
                (0, 4),
                (1, 4),
                (2, 4),
                (3, 4),
                (4, 4),
                (5, 4),
                (6, 2),
                (7, 2),
                (8, 0),
                (9, 2),
                (11, 4),
                (12, 4),
                (13, 4),
                (14, 4),
            ],
        )?;
        let name = site.string(values.get(&0).copied().unwrap_or(0))?;
        if !valid_name(&name)
            || output
                .iter()
                .any(|control: &PersistedControl| control.name.eq_ignore_ascii_case(&name))
        {
            return Err(format!("invalid or duplicate control name {name:?}"));
        }
        if let Some(count) = values.get(&1) {
            site.string(*count)?;
        }
        let (left, top) = if mask & (1 << 8) != 0 {
            (site.number(4)? as i32, site.number(4)? as i32)
        } else {
            (0, 0)
        };
        for bit in [11, 12, 13, 14] {
            if let Some(count) = values.get(&bit) {
                let value = site.string(*count)?;
                if !value.is_empty() && bit >= 12 {
                    return Err(format!(
                        "external control binding on {name} is not supported"
                    ));
                }
            }
        }
        if site.pos != length {
            return Err(format!("unconsumed site properties for {name}"));
        }
        array.pos += length;
        let flags = values.get(&4).copied().unwrap_or(0x33);
        if flags & 0x10 == 0 {
            return Err(format!(
                "nested control storage for {name} is not supported"
            ));
        }
        let kind = match values.get(&7).copied().unwrap_or(0x7fff) {
            21 => ControlKind::Label,
            17 => ControlKind::CommandButton,
            23 => ControlKind::TextBox,
            26 => ControlKind::CheckBox,
            other => {
                return Err(format!(
                    "unsupported cached control class {other} for {name}"
                ))
            }
        };
        let length = values
            .get(&5)
            .copied()
            .ok_or("missing control stream size")? as usize;
        let end = object_pos
            .checked_add(length)
            .ok_or("control stream size overflow")?;
        let bytes = objects
            .get(object_pos..end)
            .ok_or("control exceeds object stream")?;
        let mut control = decode_control(bytes, kind)?;
        control.name = name;
        control.left = points(left);
        control.top = points(top);
        control.visible = flags & 2 != 0;
        control.tab_stop = flags & 1 != 0;
        control.tab_index = values.get(&6).copied().unwrap_or(0) as i16;
        control.default_button = flags & 4 != 0;
        control.cancel_button = flags & 8 != 0;
        output.push(control);
        object_pos = end;
    }
    if array.pos != array.bytes.len() || object_pos != objects.len() {
        return Err("unaccounted form/control stream data".into());
    }
    Ok(output)
}

fn points(himetric: i32) -> f64 {
    f64::from(himetric) * 72.0 / 2540.0
}

fn decode_control(bytes: &[u8], kind: ControlKind) -> Result<PersistedControl> {
    let morph = matches!(kind, ControlKind::TextBox | ControlKind::CheckBox);
    let (mut data, mask, end) = record(bytes, 0x0200, morph)?;
    let layout: &[(u8, usize)] = if morph {
        &[
            (0, 4),
            (1, 4),
            (2, 4),
            (3, 4),
            (4, 1),
            (5, 1),
            (6, 1),
            (7, 1),
            (8, 0),
            (9, 2),
            (10, 4),
            (11, 2),
            (12, 2),
            (13, 2),
            (14, 2),
            (15, 2),
            (16, 1),
            (17, 1),
            (18, 1),
            (20, 1),
            (21, 1),
            (22, 4),
            (23, 4),
            (24, 4),
            (25, 4),
            (26, 4),
            (27, 2),
            (28, 2),
            (29, 2),
            (31, 0),
            (32, 4),
        ]
    } else if kind == ControlKind::Label {
        &[
            (0, 4),
            (1, 4),
            (2, 4),
            (3, 4),
            (4, 4),
            (5, 0),
            (6, 1),
            (7, 4),
            (8, 2),
            (9, 2),
            (10, 2),
            (11, 2),
            (12, 2),
        ]
    } else {
        &[
            (0, 4),
            (1, 4),
            (2, 4),
            (3, 4),
            (4, 4),
            (5, 0),
            (6, 1),
            (7, 2),
            (8, 2),
            (9, 0),
            (10, 2),
        ]
    };
    let values = fields(&mut data, mask, layout)?;
    let (caption, value, width, height, various) = if morph {
        if mask & ((1 << 27) | (1 << 28)) != 0 {
            return Err("control picture streams are not supported".into());
        }
        let expected_style = if kind == ControlKind::TextBox { 1 } else { 4 };
        if values.get(&6).copied().unwrap_or(1) != expected_style {
            return Err("morph display style differs from its control class".into());
        }
        if values.get(&3).copied().unwrap_or(0) != 0 || values.get(&9).copied().unwrap_or(0) != 0 {
            return Err("MaxLength/PasswordChar persistence is not supported".into());
        }
        if mask & (1 << 8) == 0 {
            return Err("morph control has no size".into());
        }
        let width = data.number(4)? as i32;
        let height = data.number(4)? as i32;
        let value = data.string(values.get(&22).copied().unwrap_or(0))?;
        let caption = data.string(values.get(&23).copied().unwrap_or(0))?;
        if let Some(count) = values.get(&32) {
            if !data.string(*count)?.is_empty() {
                return Err("control GroupName persistence is not supported".into());
            }
        }
        (
            caption,
            value,
            width,
            height,
            values.get(&0).copied().unwrap_or(0x2c80081b),
        )
    } else {
        let pictures = if kind == ControlKind::Label {
            (1 << 10) | (1 << 12)
        } else {
            (1 << 7) | (1 << 10)
        };
        if mask & pictures != 0 {
            return Err("control picture streams are not supported".into());
        }
        let caption = data.string(values.get(&3).copied().unwrap_or(0))?;
        if mask & (1 << 5) == 0 {
            return Err("control has no size".into());
        }
        let width = data.number(4)? as i32;
        let height = data.number(4)? as i32;
        (
            caption,
            String::new(),
            width,
            height,
            values.get(&2).copied().unwrap_or(0x0080001b),
        )
    };
    if data.pos != end || width <= 0 || height <= 0 {
        return Err("invalid control property size".into());
    }
    let (font_name, font_size) =
        decode_text_props(bytes.get(end..).ok_or("missing text properties")?)?;
    Ok(PersistedControl {
        name: String::new(),
        kind,
        left: 0.0,
        top: 0.0,
        width: points(width),
        height: points(height),
        caption,
        value,
        visible: true,
        enabled: various & 2 != 0,
        tab_stop: true,
        tab_index: 0,
        default_button: false,
        cancel_button: false,
        word_wrap: various & (1 << 23) != 0,
        font_name,
        font_size,
    })
}

fn decode_text_props(bytes: &[u8]) -> Result<(String, f64)> {
    let (mut data, mask, end) = record(bytes, 0x0200, false)?;
    let values = fields(
        &mut data,
        mask,
        &[(0, 4), (1, 4), (2, 4), (4, 1), (5, 1), (6, 1), (7, 2)],
    )?;
    let font = if let Some(count) = values.get(&0) {
        data.string(*count)?
    } else {
        "MS Sans Serif".into()
    };
    if !["Tahoma", "MS Sans Serif", "Microsoft Sans Serif"]
        .iter()
        .any(|name| font.eq_ignore_ascii_case(name))
    {
        return Err(format!(
            "font {font:?} is not supported by the current renderer"
        ));
    }
    if values.get(&1).copied().unwrap_or(0) != 0 || values.get(&7).copied().unwrap_or(400) != 400 {
        return Err("font effects/weight persistence is not supported".into());
    }
    if data.pos != end || end != bytes.len() {
        return Err("unaccounted text property data".into());
    }
    let twips = values.get(&2).copied().unwrap_or(160);
    if twips == 0 || twips > 4_294_967 {
        return Err("invalid persisted font height".into());
    }
    Ok((font, f64::from(twips) / 20.0))
}
