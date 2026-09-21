# MSForms facade and runtime boundary

Status: contract and executable discovery probes established by `oxforms-jbjp.6`;
acceptance remains blocked. This is not a delivered full-library facade.

## Compatibility target

The user-confirmed target on 2026-09-21 is that existing VBA projects using
forms and Microsoft-supplied controls compile and run without source changes
with OxVba and OxForms. Third-party controls are excluded. Microsoft controls
outside FM20, including RefEdit and the Common Controls libraries, are included
in that eventual target; `oxforms-tst7` owns their inventory and separate plan.
Their coverage cannot be inferred from W010 MSForms evidence.

Unchanged means preserving application modules, form modules, event-handler
names/signatures, referenced library identities and reference priority, designer
control names, persisted properties/resources, and dynamic construction strings.
The loader may substitute the implementation of a known Microsoft reference;
it must not require users to rename types, add adapters, replace event handlers,
or rewrite `Set`, default-member, collection, or form-instance expressions.

OxForms owns forms behavior and controls. OxVba owns parsing, binding, references,
execution, and FormModule integration. OxDoc owns Office containers and VBA
project import/export. Application object models and services remain host-owned.
The combined system must supply those dependencies for an unchanged application;
forms compatibility alone cannot promise arbitrary Excel/Word/Access application
code already works. These ownership boundaries do not remove forms requirements.

## Reference identity and exact public shape

The public reference is **MSForms**, LIBID
`{0D452EE1-E08F-101A-852E-02608C4D0BB4}`, version 2.0. Preserve the originating
LCID, platform, reference ordering and GUID-based resolution information. A host
reference resolver selects OxForms by that identity before binding; callers
continue to write `MSForms.TextBox`, `MSForms.Label`, `MSForms.Control`, etc.
An unresolved reference must produce an explicit diagnostic. A project named
`OxForms` or a collection of classes copied into the application is insufficient.
No FM20 registration or Microsoft control binary is required by the target
runtime. The resolver substitution itself is still an implementation obligation.

The generated [facade ledger](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.6/msforms_facade_ledger.v1.json)
maps all 183 primary FM20/stdole type contracts and 3,632 primary member contracts
to exact owners, names, invocation kinds and source-signature digests. Its
`base_ledger` pins the immutable `.4` source; references resolve into that file,
not into an approximate new set of declarations. This bead leaves the input
bytes unchanged. A later implementation/dependency baseline update must
explicitly regenerate the comparison and review/version this companion's pins;
the current snapshot is not a claim about all future source revisions.
Its 37 dual companions remain
separate ABI identities in the base. Every hidden/versioned/HTML primary type
is present; hidden/non-browsable flags do not remove a public obligation.

- Coclasses keep their exact names, CLSIDs, creatability and implemented-interface
  edges. `OptionButtonControl` is not an acceptable public replacement for
  `MSForms.OptionButton`.
- Dispatch/supporting interfaces and returned objects retain exact names,
  identity relationships and signatures. Enum values and aliases retain their
  raw values/targets. `Font`, `Picture` and stdole identities must not become
  unrelated look-alike classes.
- Each `get`, `put`, and `putref` remains distinct: `Property Get`, `Property Let`,
  and `Property Set` are source shapes, with exact parameter/return/default
  contracts referenced by the row. Preserve object identity for `Set`, including
  aliasing and `Nothing`; a successful value assignment proves no putref behavior.
- DISPID 0 supplies the canonical default member in value, assignment, indexed,
  argument and late-bound contexts. An explicit `.Value` call does not prove an
  omitted member. Preserve the separate `_NewEnum` identity at DISPID -4.
- Raw native-pointer/non-dispatch interfaces are explicit ABI adapter obligations.
  They must not be fabricated as ordinary legal VBA methods. Restricted members
  remain inventoried and excluded only by their exact authoritative flags.

## Control-site and host composition

Raw `IControl` and each intrinsic default interface stay separate. Container
sites provide extender state and methods on concrete control instances. The
companion ledger has 52 raw Control-member projections for each of 50 FCONTROL
coclasses plus returned `Page`: 2,652 obligations. Of these, 357 are explicitly
restricted; 2,295 still require applicability evidence. FCONTROL is a candidate
signal, not proof of a particular site member. Root UserForm and returned Page
contexts need their own decisions.

Each row cites the owner, exact Control declaration/accessors, and any native
member name collision. Collision precedence, DISPIDs, default selection and
early/late binding must be decided from exact host observations. Do not let a
standalone `Control.Name` test satisfy `TextBox.Name`, or let a canonical class
satisfy its versioned/HTML counterpart. No member is copied into the raw facts.

The four generic host events `Enter`, `Exit`, `BeforeUpdate`, `AfterUpdate`
likewise have 204 owner-specific applicability rows. Ten prior attachments are
retained as observations; 194 remain unresolved. Even an observed attachment
does not prove ordering, cancellation, mutation or reentrancy. Handlers bind to
the concrete site/control sender, with exactly the raw event signatures.

The base host overlay remains mandatory alongside `_UserForm`: generated
FormModule members and instances, `Me`, designer-named fields and handler
connections, default/predeclared instances, `Load`/`Unload`, `Show`/`Hide`,
modal/modeless behavior, and the intrinsic global `UserForms` collection.
Overlay documentation must not invent COM DISPIDs or missing parameter details.
`.44`/`.57` retain the FormModule handover and integration implementation.

## Construction and ProgIDs

The ledger records the fourteen intrinsic `Forms.<Control>.1` names documented
by Microsoft's [Add method reference](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/add-method-microsoft-forms)
(checked 2026-09-21). The factory must resolve these strings to exact classes
and preserve container ownership, optional arguments and host-visible behavior.
Returned Pages/Tabs use their own collection construction. A typelib name alone
does not establish a ProgID; other/versioned/HTML names remain explicit unresolved
construction rows until the exact registration/export/probe authority is joined.
Do not synthesize `.2` names from a type-name suffix.

## Callable designer-band properties

The scope includes `DesignMode`, `ShowToolbox`, `ShowGridDots`, `SnapToGrid`,
`GridX`, `GridY` on `_UserForm`, `IOptionFrame`, and `IPage`, plus
`_UserForm.DrawBuffer`. All nineteen declarations remain accepted pending
runtime probes. The discovery harness generates separate get and put operations
for all 38 accessors on a live UserForm, Frame and Page, using late-bound objects
to observe dispatch behavior even when source browsing hides a member.

A runtime error is an observation, not permission to exclude the member. A
setter that rejects a particular value, mode or host may still be callable.
Record value/type, exact Err fields, target context and accessor independently;
then specify its supported/error behavior. Designer UI implementation is outside
this bead; callable properties bearing designer-related names are not.

## One internal runtime bridge

The target bridge is a single non-public host capability, `OxFormsRuntime.Dispatch`.
It carries an internal operation code, runtime/control identity and typed payload
across the host/runtime boundary. The host obtains it through runtime registration,
never through the application's MSForms reference or a public control member.
Operations cover realization, input/event delivery, layout/render invalidation,
effect readback and teardown. Their payload schema belongs to `.7` alongside
implementation; numeric codes must not enter the public compatibility contract.

Public controls expose only their accepted raw/site/host contracts. Existing
`Core`, `Perform*`, `Notify*`, diagnostics and renderer helpers migrate behind
the bridge in `.7`; this bead introduces no production shim or duplicate path.
The Rust PAL remains control-blind and small. Internal control/state objects
cannot escape through public properties or automation enumeration.

The pinned OxVba baseline currently allows external calls to `Friend` members.
Consequently a `Friend` declaration alone cannot satisfy this boundary. The
bridge requires a compiler/runtime visibility guarantee and a host-only handle;
both early-bound and `Object`/late-bound external access must be rejected.
Do not rename internal hooks to obscure them and claim they became private.

## Executable coverage and outstanding proof

`oxvba_w010_facade_contract.rs` binds two separate projects and runs their linked
OxIR image. Small non-production classes isolate the relevant mechanisms. The
put/putref fixture uses an explicitly synthetic `SetterMechanismProbe`; it is
not an accepted MSForms type, and must not be confused with `TextBox.Value`,
which has no raw putref accessor. It
proves qualified `MSForms` construction, explicit property binding, value versus
object setters, alias identity and same-library Friend invocation. It also
reproduces two failures: scalar default-member coercion through qualified referenced types and
external Friend visibility. The discrepancy assertions passing means the failures
still reproduce; it does not mean compatibility passes.

The exact failures and required outcomes are recorded in
[the OxVba handover](../handovers/HANDOVER_OxVba_w010_facade_binding.md) and
[the discrepancy register](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.6/DISCREPANCIES.md).
`oxforms-o0fp` blocks `.6`. Reference substitution by LIBID, real production
class exposure, the full default-member context matrix, callable hidden probes,
construction identities and unresolved site/event applicability remain explicit
obligations. Contract inventory and green infrastructure tests do not close them.
