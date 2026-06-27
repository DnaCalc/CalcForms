# FM20 Event Facts

Status: W005 curated fact surface.
Owning bead: `oxforms-xvx.17`.
Raw metadata evidence:
[`../evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json`](../evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json).

This document establishes the W005 FM20/MSForms event signature and argument
surface used by oracle fixtures, trace schemas, and eventual VBA event dispatch.
It is not a complete FM20 event model and does not implement runtime behavior.

## Evidence Classes

Facts in this file use these classes:

- `metadata`: public FM20 type-library metadata loaded from `FM20.DLL`.
- `public-doc`: public Microsoft Learn VBA/MSForms documentation.
- `observed`: repo-owned or black-box MSForms observations. This bead adds no
  live MSForms event observation rows.
- `assumption`: a W005 design expectation that still needs fixture evidence.
- `unknown`: intentionally unresolved because neither public metadata nor
  committed observation settles it yet.

Public metadata source:

- `C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL`
- Library: `MSForms`, "Microsoft Forms 2.0 Object Library"
- Library GUID: `{0D452EE1-E08F-101A-852E-02608C4D0BB4}`, version `2.0`
- SHA-256:
  `E5085D8229D72180C7F2D8762E1A49FFF18A04F0143D7A973FF1FBC6200CB81E`

Public documentation anchors:

- Microsoft Learn:
  [CheckBox control](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/checkbox-control),
  [TripleState property](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/triplestate-property),
  [Click event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/click-event),
  [DblClick event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dblclick-event),
  [Change event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/change-event),
  [Enter/Exit events](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/enter-exit-events),
  [BeforeUpdate event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/beforeupdate-event),
  [AfterUpdate event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/afterupdate-event),
  [KeyDown/KeyUp events](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/keydown-keyup-events),
  [KeyPress event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/keypress-event),
  [MouseDown/MouseUp events](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mousedown-mouseup-events),
  [MouseMove event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mousemove-event),
  [Error event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/error-event),
  [DropButtonClick event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dropbuttonclick-event),
  [BeforeDragOver event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/beforedragover-event),
  [BeforeDropOrPaste event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/beforedroporpaste-event),
  [Initialize event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/initialize-event),
  [Activate/Deactivate events](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/activate-deactivate-events),
  [QueryClose event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/queryclose-event),
  [Resize event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/resize-event),
  [Terminate event](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/terminate-event-visual-basic-for-applications).

## Interpretation Rules

- FM20 source event interfaces are dispatch interfaces attached to coclasses as
  source interfaces. Their members supply DISPIDs and raw argument types.
- The raw metadata represents mutable helper arguments as `VT_PTR` to
  `MSForms.ReturnBoolean`, `MSForms.ReturnInteger`,
  `MSForms.ReturnString`, `MSForms.ReturnSingle`, or
  `MSForms.ReturnEffect`, with `PARAMFLAG_FIN`. Microsoft Learn syntax exposes
  these as `ByVal <arg> As MSForms.Return*`. W005 should treat them as mutable
  helper objects, not as scalar `ByRef` parameters.
- Plain scalar or enum arguments in the raw metadata are `PARAMFLAG_FIN` and are
  treated as non-mutable unless public docs or black-box observation proves a
  special case.
- Mouse and drag/drop `X`/`Y` arguments are `Single`. Microsoft Learn describes
  them as points from the left/top edge of the receiving target. The exact
  relation to screenshot pixels, DPI scaling, and OxForms coordinate spaces is
  owned by [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md).
- Event ordering snippets in Microsoft Learn are public-doc facts. W005 still
  needs black-box event logs before claiming full ordering parity.

## Argument Direction And Mutability Summary

| Argument class | Raw metadata shape | VBA/public-doc shape | W005 mutability treatment | Events using it |
|---|---|---|---|---|
| `MSForms.ReturnBoolean` helper | `VT_PTR` to `ReturnBoolean`, `PARAMFLAG_FIN` | `ByVal Cancel As MSForms.ReturnBoolean` or `ByVal CancelDisplay As MSForms.ReturnBoolean` | Mutable helper object; log `.Value` before and after dispatch. Not a scalar `ByRef Boolean`. | `DblClick`, `Exit`, `BeforeUpdate`, `Error`, `BeforeDragOver`, `BeforeDropOrPaste` |
| `MSForms.ReturnInteger` helper | `VT_PTR` to `ReturnInteger`, `PARAMFLAG_FIN` | `ByVal KeyCode As MSForms.ReturnInteger`, `ByVal KeyAscii/KeyANSI As MSForms.ReturnInteger` | Mutable helper object; exact effect of assigning `.Value` remains `unknown` until observed. | `KeyDown`, `KeyUp`, `KeyPress` |
| `MSForms.ReturnString` helper | `VT_PTR` to `ReturnString`, `PARAMFLAG_FIN` | `ByVal Description As MSForms.ReturnString` | Mutable helper object; exact display/error effect remains `unknown`. | `Error` |
| `MSForms.ReturnEffect` helper | `VT_PTR` to `ReturnEffect`, `PARAMFLAG_FIN` | `ByVal Effect As MSForms.ReturnEffect` | Mutable helper object; `oxforms-0a0.15` records helper-result boundaries for the first text-only drag/drop subset, while broad mutation behavior remains deferred. | `BeforeDragOver`, `BeforeDropOrPaste` |
| `MSForms.ReturnSingle` helper | `VT_PTR` to `ReturnSingle`, `PARAMFLAG_FIN` | No W005 probe handler uses it directly. | Mutable helper object; deferred. | `Scroll` |
| Object reference | `VT_PTR` to `Control` or `DataObject`, `PARAMFLAG_FIN` | Public docs vary between omitted `ByVal` and `ByVal`, depending on event page/source shape. | Treat as an object reference; do not claim full object mutation semantics in W005. | `AddControl`, `RemoveControl`, drag/drop events |
| Scalar or enum value | `VT_I2`, `VT_I4`, `VT_R4`, `VT_BSTR`, or `VT_USERDEFINED`, usually `PARAMFLAG_FIN` | `ByVal` scalar or enum in public docs, except lifecycle `QueryClose` docs use plain `Integer` params. | Non-mutable unless black-box observation proves otherwise. `BeforeDropOrPaste.Action` is explicitly `unknown` because docs describe updating it despite by-value metadata/docs syntax. | Mouse/key modifiers, coordinates, `fmAction`, `fmDragState`, `SCode`, strings, lifecycle `CloseMode` |

## Source Interfaces Relevant To W005

| Source interface | Coclasses in raw metadata | W005 relevance |
|---|---|---|
| `ControlEvents` | `Control` | Generic focus/update events: `Enter`, `Exit`, `BeforeUpdate`, `AfterUpdate`. Specific W005 probe exposure must be confirmed by fixtures. |
| `FormEvents` | `UserForm`, `UserForm2` | Form mouse/key/drag/drop plus `AddControl`, `RemoveControl`, `Layout`, `Scroll`, `Zoom`. Does not include `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize`, or `Terminate` in this FM20 capture. |
| `OptionFrameEvents` | `Frame`, `Frame2` | Same broad event shape as `FormEvents` for container probes and future nested routing. |
| `LabelControlEvents` | `Label`, `Label2` | W005 `Label` mouse/click/drag/drop/error facts. No key, change, enter, exit, or update events on this source interface. |
| `CommandButtonEvents` | `CommandButton`, `CommandButton2` | W005 `CommandButton` click, keyboard, mouse, drag/drop, and error facts. |
| `MdcTextEvents` | `TextBox`, `TextBox2` | W005 `TextBox` change, keyboard, mouse, drag/drop, drop-button, double-click, and error facts. No `Click` member on this source interface. |

## W005 Probe Subset

Legend:

- `probe`: event is in the first W005 Label/CommandButton/TextBox/UserForm
  fixture vocabulary.
- `deferred`: event is recorded here but full behavior belongs to a later
  drag/drop, validation, lifecycle, or control-breadth bead.
- `not-probe`: event is outside the named W005 probe subset.
- `unknown`: public metadata/docs do not settle enough for probe use.

| Event | Probe status | Public metadata applicability | DISPID facts | Argument facts | Mutation/cancel facts | Coordinate/order facts and unknowns |
|---|---|---|---|---|---|---|
| `Click` | `probe` for `Label`, `CommandButton`, `UserForm`; absent from `TextBox` source interface | `LabelControlEvents`, `CommandButtonEvents`, `FormEvents`, `OptionFrameEvents`, plus other non-probe controls. `MdcTextEvents` has no `Click`. | `-600` for W005 `Label`, `CommandButton`, `UserForm`; `-610` on several value-selection controls outside W005 probe. | No args for W005 probe sources. `MultiPage`/`TabStrip` add `index As Long` outside probe. | None. | Public docs describe `MouseDown -> MouseUp -> Click` for mouse click. Docs also say `CommandButton` focus `Enter` can precede `Click`; exact W005 order remains `unknown` until oracle capture. |
| `DblClick` | `probe` for `Label`, `CommandButton`, `TextBox`, `UserForm` | `LabelControlEvents`, `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other controls. | `-601` on all W005 probe sources. | `Cancel As MSForms.ReturnBoolean`. `MultiPage`/`TabStrip` add leading `index As Long` outside probe. | `Cancel` is a mutable return-helper object. Public docs say setting it true lets the application handle/ignore the second click. | Public docs show `MouseDown -> MouseUp -> Click -> DblClick` when `Click` is supported; for `TextBox`, `Click` is omitted. Exact double-click synthesis is `unknown` until oracle capture. |
| `Change` | `probe` for `TextBox`; broader controls deferred | `MdcTextEvents` for `TextBox`; also list/combo/check/option/toggle/scroll/spin/tab/multipage source interfaces. Not on `LabelControlEvents` or `CommandButtonEvents`. | `2`. | No args. | None. | Public docs tie it to `Value` changes from code or user action. Key/edit ordering is `unknown` until TextBox oracle capture. |
| `Enter` | `probe` for focusable `CommandButton` and `TextBox` as an expected fixture event; `Label` not focusable by default | `ControlEvents` on generic `Control` coclass. Not present on the specific W005 probe source interfaces in this raw FM20 capture. | `-2147384830`. | No args. | None. | Public docs say `Enter` occurs before a control receives focus from another control on the same form. Per-coclass sink exposure and exact focus ordering are `unknown` until fixture/VBE observation. |
| `Exit` | `probe` for focusable `CommandButton` and `TextBox` as an expected fixture event; validation detail deferred | `ControlEvents` on generic `Control` coclass. Not present on specific W005 probe source interfaces in this raw capture. | `-2147384829`. | `Cancel As MSForms.ReturnBoolean`. | `Cancel` is a mutable return-helper object. Public docs say setting it true keeps focus at the current control. | Public docs place `Exit` immediately before focus leaves for another control on the same form. Per-probe sink exposure remains `unknown`. |
| `KeyDown` | `probe` for `CommandButton`, `TextBox`, `UserForm`; absent from `Label` source interface | `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other focusable controls. | `-602`. | `KeyCode As MSForms.ReturnInteger`, `Shift As Integer` (`fmShiftState` in docs). | `KeyCode` is a mutable return-helper object; exact effect of mutation must be observed. `Shift` is scalar. | Public docs say keyboard sequence is `KeyDown -> KeyPress -> KeyUp` for ANSI input and that default/cancel buttons can suppress key events for Enter/Esc. Exact W005 routing is `unknown`. |
| `KeyUp` | `probe` for `CommandButton`, `TextBox`, `UserForm`; absent from `Label` source interface | `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other focusable controls. | `-604`. | `KeyCode As MSForms.ReturnInteger`, `Shift As Integer` (`fmShiftState` in docs). | `KeyCode` is a mutable return-helper object; exact effect of mutation must be observed. `Shift` is scalar. | Public docs put `KeyUp` after key-triggered control events; focus transfer can move `KeyPress`/`KeyUp` to a second control. W005 needs black-box logs. |
| `KeyPress` | `probe` for `TextBox`; possible `CommandButton`/`UserForm` diagnostics; absent from `Label` source interface | `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other focusable controls. | `-603`. | Metadata argument name is `KeyAscii As MSForms.ReturnInteger`. Microsoft Learn syntax currently uses `KeyANSI`; examples commonly use `KeyAscii`. Treat the exact VBE stub spelling as `unknown` until fixture generation observes it. | `KeyAscii`/`KeyANSI` is a mutable return-helper object; exact effect of mutation must be observed. | Public docs limit it to ANSI/typeable keys and exclude Tab, Enter, arrow keys, and focus-moving keystrokes. |
| `MouseDown` | `probe` for `Label`, `CommandButton`, `TextBox`, `UserForm` | `LabelControlEvents`, `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other mouse-capable controls. | `-605`. | `Button As Integer` (`fmButton` in docs), `Shift As Integer` (`fmShiftState` in docs), `X As Single`, `Y As Single`. | No mutable args. | Public docs define `X`/`Y` as point coordinates and describe capture from mouse down until final mouse up. Exact live target-local rounding and pixel relation are owned by [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md). |
| `MouseUp` | `probe` for `Label`, `CommandButton`, `TextBox`, `UserForm` | Same W005 sources as `MouseDown`. | `-607`. | `Button As Integer`, `Shift As Integer`, `X As Single`, `Y As Single`. | No mutable args. | Public docs include click ordering and capture semantics. W005 must log captured/out-of-bounds coordinates in oracle fixtures. |
| `MouseMove` | `probe` for `Label`, `CommandButton`, `TextBox`, `UserForm` | Same W005 sources as `MouseDown`. | `-606`. | `Button As Integer`, `Shift As Integer`, `X As Single`, `Y As Single`. | No mutable args. | Public docs say it fires repeatedly as the pointer moves and uses points from the left/top edge of the control. Capture and no-capture routing need oracle evidence. |
| `BeforeUpdate` | `probe` for `TextBox` validation ordering; broader behavior deferred | `ControlEvents` on generic `Control` coclass. Not present on specific W005 probe source interfaces in this raw capture. | `-2147384831`. | `Cancel As MSForms.ReturnBoolean`. | `Cancel` is a mutable return-helper object. Public docs say setting it true cancels the update and keeps focus on the control. | Public docs place it before `AfterUpdate`, `Exit`, and the next control's `Enter`. Exact TextBox mutation/validation trigger remains `unknown`. |
| `AfterUpdate` | `probe` for `TextBox` validation ordering; broader behavior deferred | `ControlEvents` on generic `Control` coclass. Not present on specific W005 probe source interfaces in this raw capture. | `-2147384832`. | No args. | None; public docs say this event cannot be canceled. | Public docs place it after `BeforeUpdate` and before `Exit`/next `Enter`. W005 needs black-box logs for actual TextBox ordering. |
| `Error` | `deferred`, but fixture may log if naturally raised | `LabelControlEvents`, `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other controls. | `-608`. | W005 probe form: `Number As Integer`, `Description As MSForms.ReturnString`, `SCode As Long`, `Source As String`, `HelpFile As String`, `HelpContext As Long`, `CancelDisplay As MSForms.ReturnBoolean`. `MultiPage` adds leading `index As Long` outside probe. | `Description` and `CancelDisplay` are mutable return-helper objects. Other args are scalar/string values. Exact UI effect of mutation needs observation. | No coordinate args. Error generation scenarios are outside W005 first probe unless encountered by oracle fixture. |
| `DropButtonClick` | `deferred`; record for TextBox source surface but do not require first TextBox probe behavior | `MdcTextEvents` for `TextBox`; `MdcComboEvents` for `ComboBox`. | `2002`. | No args. | None. | Public docs say it occurs when the dropdown appears or disappears, including `DropDown`, button click, and F4 paths. W005 TextBox drop-button applicability needs fixture/property setup. |
| `BeforeDragOver` | `deferred`; W005 records signature for future drag/drop traces | `LabelControlEvents`, `CommandButtonEvents`, `MdcTextEvents`, `FormEvents`, `OptionFrameEvents`, plus other controls. | `3`. | For `Label`/`CommandButton`/`TextBox`: `Cancel As MSForms.ReturnBoolean`, `Data As MSForms.DataObject`, `X As Single`, `Y As Single`, `DragState As MSForms.fmDragState`, `Effect As MSForms.ReturnEffect`, `Shift As Integer`. `UserForm`/`Frame` add `Control As MSForms.Control` before `Data`; `MultiPage`/`TabStrip` add index variations outside W005 probe. | `Cancel` and `Effect` are mutable return-helper objects. `Data` is an object reference. | Public docs define `X`/`Y` as point coordinates from the control's left/top edge and describe `DragState`. Full drag/drop behavior is outside W005 first probe. |
| `BeforeDropOrPaste` | `deferred`; W005 records signature for future drag/drop/paste traces | Same broad source applicability as `BeforeDragOver`. | `4`. | For `Label`/`CommandButton`/`TextBox`: `Cancel As MSForms.ReturnBoolean`, `Action As MSForms.fmAction`, `Data As MSForms.DataObject`, `X As Single`, `Y As Single`, `Effect As MSForms.ReturnEffect`, `Shift As Integer`. `UserForm`/`Frame` add `Control As MSForms.Control`; `MultiPage`/`TabStrip` add index variations outside W005 probe. | `Cancel` and `Effect` are mutable return-helper objects. `Data` is an object reference. Public docs describe updating `Action`, but metadata/docs syntax show `Action` as a by-value enum; W005 treats `Action` mutation as `unknown` until black-box observation. | Public docs define drop `X`/`Y` as point coordinates from the control's left/top edge. Full paste/data-object semantics are deferred. |

## W006 Deferred Input Surface Fact Split

`oxforms-0a0.6` does not add live MSForms observations. It separates the public
facts above from design assumptions for future IME, clipboard, paste, and
drag/drop work.

Public facts available now:

- `KeyDown`, `KeyUp`, and `KeyPress` signatures and public-doc keyboard notes
  are fact-backed by the event rows above. Public docs limit `KeyPress` to
  ANSI/typeable input and exclude Tab, Enter, arrow keys, and focus-moving
  keystrokes.
- `Change` has no arguments and public docs tie it to control value changes from
  code or user action, but exact TextBox ordering remains unknown.
- `BeforeDragOver` and `BeforeDropOrPaste` signatures are fact-backed for
  `Label`, `CommandButton`, `TextBox`, `UserForm`, and related source
  interfaces. They include `MSForms.DataObject`, point coordinates, shift state,
  mutable `Cancel`, and mutable `Effect`.
- Public docs describe drag/drop `X`/`Y` as points from the target's left/top
  edge. Coordinate conversion remains owned by `COORDINATE_MODEL.md`.

Repo-owned observations available now:

- `oxforms-0a0.13` captures live Excel/MSForms `TextBox.Paste` evidence under
  `docs/evidence/W006_control_implementation_rollout/captures/text-service-transfer-20260623T084627Z/`.
  For the repo-owned text clipboard seed, MSForms raised `BeforeDropOrPaste`
  before `Change`.
- The observed `BeforeDropOrPaste` row records `X = 0`, `Y = 0`, `Shift = 0`,
  `Action = 2`, `Cancel` before/after `False` -> `False`, and `Effect`
  before/after `0` -> `0`.
- The observed `DataObject` row records only public method summaries:
  `GetFormat(1) = True` and `GetText(1)` matching the repo-owned seed id. It
  stores no live COM object identity and no unexpected clipboard payload text.
- The same capture records exact blockers for `Ctrl+V` keyboard delivery,
  IME/composition, dead-key preedit, and true OLE drag/drop. No keyboard
  shortcut ordering, IME/dead-key behavior, `BeforeDragOver`, or drag-session
  `DataObject` behavior is claimed from the `.13` paste run.
- `oxforms-0a0.17` records a clean live Excel/MSForms `Ctrl+V` keyboard-driver
  blocker under
  `docs/evidence/W006_control_implementation_rollout/captures/text-service-transfer-20260623T102142Z/`.
  `SetForegroundWindow` returned `False`, public `user32 SendInput` requested 4
  keyboard inputs but sent 0 with last Win32 error 87, and
  `System.Windows.Forms.SendKeys.SendWait("^v")` failed with access denied.
  The run then used public `TextBox.Paste` fallback and observed the same
  `BeforeDropOrPaste` -> `Change` paste shape as `.13`. No keyboard shortcut
  `KeyDown`/`KeyPress`/`KeyUp` ordering is claimed from `.17`.
- `oxforms-0a0.16` captures separate live Excel/MSForms true drag/drop evidence
  under
  `docs/evidence/W006_control_implementation_rollout/captures/ole-drag-drop-transfer-20260623T093507Z/`.
  The repo-owned source calls public `MSForms.DataObject.StartDrag`; target
  `BeforeDragOver` rows precede one `BeforeDropOrPaste` row; the drop row
  records `X = 63`, `Y = 15`, `Shift = 0`, `Action = 3`, `Cancel`
  `False` -> `False`, `Effect` `1` -> `1`, and a public `DataObject` summary
  with `GetFormat(1) = True` for the repo-owned drag seed id. This is true
  drag/drop evidence, separate from `.13` paste evidence.

OxForms implementation relying on those observations:

- `oxforms-0a0.14` implements only a host-neutral text-only paste subset for
  focused single-line TextBox state. A successful normalized
  `ClipboardResult(Get)` with accepted plain-text format and serializable text
  payload emits `BeforeDropOrPaste` metadata before `Change`, then repaint, and
  replaces the current TextBox selection. Its `BeforeDropOrPaste` `Data`
  argument is a serializable payload summary, not a live `MSForms.DataObject`.
- Unsupported clipboard formats and missing/failed text payloads are recorded
  as diagnostics and do not mutate TextBox state. The subset does not claim
  `Ctrl+V` shortcut ordering, menu paste, rich formats, true drag/drop,
  IME/dead-key behavior, broad `DataObject` parity, `Action` mutation, handler
  cancellation behavior, or native FM20-named OxVba dispatch.
- `oxforms-0a0.15` implements only a host-neutral text-only true drag/drop
  subset for TextBox targets. Normalized `DragOver` rows emit
  `BeforeDragOver` metadata in the public argument order above. Normalized
  `DropOrPaste` rows whose origin is `DragDrop` and whose serializable
  `DataObjectSnapshot` contains accepted plain text emit
  `BeforeDropOrPaste` metadata before `Change` and repaint, and insert the text
  into the target/focused TextBox. The `Data` argument is a serializable
  snapshot summary, not a live `MSForms.DataObject`. Dispatch metadata cites
  this file and records headless/helper result boundaries for `Cancel` and
  `Effect` when the core path attempts dispatch. Other `DropOrPaste` origins,
  unsupported formats, missing/unsupported text, and missing TextBox targets are
  diagnostic no-ops. A replayed true drag/drop trace may use
  `UiEventSource::Replay` while keeping `DropOrPasteOrigin::DragDrop`; this is
  not the same as the unsupported `DropOrPasteOrigin::Replay`. This subset
  relies on the `.16` true drag/drop oracle only for the repo-owned text-drop
  shape; rich formats, cross-application drag sources, cancellation/mutation
  breadth, final MSForms ordering, broad `DataObject` parity, and native
  FM20-named OxVba dispatch remain non-claims.

Design assumptions that are not facts:

- Clipboard shortcut routing through `KeyDown`/`KeyUp`, followed by a host/PAL
  `ClipboardGet` effect, remains an OxForms architecture assumption. The
  `oxforms-0a0.17` capture improves the blocker diagnostics but does not
  observe a completed Ctrl+V keyboard shortcut.
- Representing `MSForms.DataObject` as a serializable snapshot plus an
  adapter-owned live object during dispatch is an OxForms layering assumption.
  The raw public fact is only that the event argument is a `DataObject`
  reference.
- IME composition and dead-key preedit are not covered by the current FM20 event
  fact rows. Any `TextComposition*` normalized events are OxForms design names
  until public platform documentation plus Office/MSForms observations settle
  ordering and mutation behavior.
- Treating `BeforeDropOrPaste.Action` as mutable is not yet a fact. The public
  docs describe updating it, while the metadata/docs syntax captured here look
  by-value; `oxforms-0a0.13` records the observed scalar value for one paste row
  but does not establish mutation behavior.

Implementation beads must cite which class they are relying on. They must not
upgrade any assumption in this section to compatibility behavior without a
repo-owned fixture, committed trace/evidence artifact, and focused tests.

## W006 CheckBox Boolean-Value Readiness Subset

Status: curated for `oxforms-0a0.11`; runtime implementation belongs to
`oxforms-0a0.12`.

This subset covers only `MSForms.CheckBox` boolean value behavior. It does not
claim `OptionButton`, `ToggleButton`, tri-state/null behavior,
`ControlSource`, drag/drop/paste, double-click, error handling, native
FM20-named OxVba dispatch, or final event-order parity.

Public fact sources:

- `metadata`: committed raw FM20 type-library rows in
  `docs/evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json`
  for coclass `CheckBox`, source interface `MdcCheckBoxEvents`.
- `public-doc`: Microsoft Learn `CheckBox control`, which describes selected
  and unselected states as Yes/True/On and No/False/Off, says `Value` is the
  default property, and says `Click` is the default event.
- `public-doc`: Microsoft Learn `TripleState property`, which says
  `TripleState=False` supports only `True` and `False` through the UI, while
  `TripleState=True` allows `Null`; `Null` is outside this first lane.

Curated event facts for the first boolean-value lane:

| Event | W006 CheckBox status | Public metadata facts | Argument facts | Readiness classification |
|---|---|---|---|---|
| `MouseDown` | in first lane | `MdcCheckBoxEvents`, DISPID `-605` | `Button As Integer`, `Shift As Integer`, `X As Single`, `Y As Single` | Fact-backed for routing/effect shape; exact live ordering and coordinate rounding remain oracle-gated. |
| `MouseMove` | in first lane | `MdcCheckBoxEvents`, DISPID `-606` | `Button As Integer`, `Shift As Integer`, `X As Single`, `Y As Single` | Fact-backed for routing/effect shape; capture/out-of-bounds behavior remains oracle-gated. |
| `MouseUp` | in first lane | `MdcCheckBoxEvents`, DISPID `-607` | `Button As Integer`, `Shift As Integer`, `X As Single`, `Y As Single` | Fact-backed for routing/effect shape; click-synthesis ordering oracle-confirmed (oxforms-p41): a mouse toggle fires `MouseUp`, then the value `Change`, then `Click`. |
| `Click` | in first lane | `MdcCheckBoxEvents`, DISPID `-610` | no args | Fact-backed as the default CheckBox event; placement relative to value mutation and `Change` is **oracle-confirmed** (oxforms-p41, capture `checkbox-click-change-20260627T162407Z`): `Change` fires **before** `Click` (value-change-first), and `Click` already sees the toggled `Value`. |
| `Change` | in first lane | `MdcCheckBoxEvents`, DISPID `2` | no args | Fact-backed as a CheckBox source event; public docs tie `Change` to `Value` changes, and order relative to `Click` is **oracle-confirmed** (oxforms-p41): the value toggles, then `Change` fires, then `Click` — both handlers read the new `Value`. |
| `KeyDown` | in first lane for keyboard diagnostics/activation | `MdcCheckBoxEvents`, DISPID `-602` | `KeyCode As MSForms.ReturnInteger`, `Shift As Integer` | Fact-backed event shape; Space/Enter activation details and `ReturnInteger` mutation effects remain oracle-gated. |
| `KeyUp` | in first lane for keyboard diagnostics/activation | `MdcCheckBoxEvents`, DISPID `-604` | `KeyCode As MSForms.ReturnInteger`, `Shift As Integer` | Fact-backed event shape; activation ordering remains oracle-gated. |
| `Enter` | focus participation only | Generic `ControlEvents`, DISPID `-2147384830` | no args | Public-doc focus fact, but CheckBox-specific sink exposure is not present in the captured `MdcCheckBoxEvents` rows; treat as unknown/blocker for native CheckBox dispatch until observed. |
| `Exit` | focus participation only | Generic `ControlEvents`, DISPID `-2147384829` | `Cancel As MSForms.ReturnBoolean` | Public-doc focus fact, but CheckBox-specific sink exposure is not present in the captured `MdcCheckBoxEvents` rows; validation/cancel behavior is outside this lane until observed. |

Deferred CheckBox events present in `MdcCheckBoxEvents` but outside this first
lane: `DblClick`, `KeyPress`, `BeforeDragOver`, `BeforeDropOrPaste`, and
`Error`.

## Lifecycle And Form-adjacent Events

The following names are needed by the W005 lifecycle/pump vocabulary. The first
group is public-doc only in this bead: the names were not found as members of
FM20 source interfaces attached to `UserForm`/`UserForm2` in the raw
`FM20.DLL` capture, so DISPIDs are unknown here.

| Event | Source class | Signature fact | Mutation/cancel facts | W005 status |
|---|---|---|---|---|
| `Initialize` | `public-doc` | `object_Initialize()` / `UserForm_Initialize()` | None. | Lifecycle fixture should log it; no FM20 DISPID from this capture. |
| `Activate` | `public-doc` | `object_Activate()` / `UserForm_Activate()` | None. | Lifecycle fixture should log it; public docs tie it to visible active-window state. |
| `Deactivate` | `public-doc` | `object_Deactivate()` / `UserForm_Deactivate()` | None. | Lifecycle fixture should log it; public docs say it does not occur when unloading. |
| `QueryClose` | `public-doc` | `UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)` | `Cancel` is a plain VBA integer parameter; setting nonzero cancels close per docs. `CloseMode` is the close reason. | Lifecycle fixture should log it; no FM20 DISPID from this capture. |
| `Resize` | `public-doc` | `UserForm_Resize()` | None. | Visible smoke/lifecycle fixture should log it when resize exists. |
| `Terminate` | `public-doc` | `object_Terminate()` / `UserForm_Terminate()` | None. | Lifecycle fixture should log it; public docs tie it to object reference lifetime after unload. |

FM20 metadata also exposes form-adjacent events on `FormEvents` and
`OptionFrameEvents`:

| Event | DISPID | Signature facts | W005 status |
|---|---:|---|---|
| `AddControl` | `768` | `Control As MSForms.Control` | Deferred to dynamic control/lifecycle work. |
| `RemoveControl` | `771` | `Control As MSForms.Control` | Deferred to dynamic control/lifecycle work. |
| `Layout` | `770` | No args. | Deferred; may matter for form/frame layout probes. |
| `Scroll` | `772` | `ActionX As MSForms.fmScrollAction`, `ActionY As MSForms.fmScrollAction`, `RequestDx As Single`, `RequestDy As Single`, `ActualDx As MSForms.ReturnSingle`, `ActualDy As MSForms.ReturnSingle` | Deferred; records mutable `ActualDx`/`ActualDy` return helpers. |
| `Zoom` | `773` | `Percent` appears as raw pointer to `VT_I2` in this capture. | Deferred; exact VBA syntax needs VBE/black-box confirmation before use. |

## Downstream Contract

Oracle fixture beads should:

- generate handlers from the event names and argument names in this file;
- log before/after `.Value` for every `MSForms.Return*` helper argument;
- log `Button`, `Shift`, `KeyCode`, `KeyAscii`/`KeyANSI`, `X`, `Y`, and the
  event target object name;
- label mouse and drag/drop coordinates as `msforms_event_args` points with
  target-local origin, preserving raw `screen_pixels`, `screenshot_pixels`,
  `form_logical`, and `control_local` coordinates per
  [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md);
- preserve the `KeyAscii` versus `KeyANSI` spelling discrepancy until the
  generated VBE fixture or black-box logs settle it.

Trace/schema and event-dispatch beads should:

- represent mutable helper arguments distinctly from scalar `ByRef`;
- cite this file for DISPIDs and argument order;
- keep ordering claims tentative unless backed by W005 event oracle evidence;
- avoid implementing drag/drop, paste, or lifecycle behavior merely because
  signatures are documented here.

## Remaining Unknowns

- Whether and how the generic `ControlEvents` source interface maps to specific
  `Label`, `CommandButton`, and `TextBox` handler stubs in the VBE/object model.
- Exact generated VBE handler spelling for `KeyPress` (`KeyAscii` metadata vs
  `KeyANSI` current public-doc syntax).
- Actual mutation effects for `ReturnInteger`, `ReturnString`, `ReturnEffect`,
  `CancelDisplay`, and the documented `BeforeDropOrPaste` `Action` update.
- Exact focus/validation ordering for `Enter`, `Exit`, `BeforeUpdate`,
  `AfterUpdate`, `Change`, keyboard events, and default/cancel activation.
- Exact live-coordinate rounding and target-local relation between MSForms
  point arguments, fixture bounds, and screenshot pixels after the W005
  calibration procedure runs.
- DISPIDs, if any, used by UserForm lifecycle events documented outside the
  FM20 source interfaces captured here.
