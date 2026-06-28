[CmdletBinding()]
param(
    [string]$TracePath = 'docs\evidence\W005_input_interaction_model_exploration\trace-replay\synthetic-click-trace.v1.json',
    [string]$SchemaPath = 'docs\schemas\trace-replay-artifact.v1.schema.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-RepoPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path value is empty.'
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not ($fullPath.Equals($repoRoot, $comparison) -or $fullPath.StartsWith($repoWithSeparator, $comparison))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Assert-RepoRelativeArtifactPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ([System.IO.Path]::IsPathRooted($Path) -or $Path -match '^[\\/]{1,2}') {
        throw "$Context must be repository-relative, got '$Path'."
    }
    if ($Path -match '\\') {
        throw "$Context must use forward slashes, got '$Path'."
    }
    if ($Path -split '/' | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) {
        throw "$Context contains an invalid path segment: '$Path'."
    }
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NonEmptyString {
    param(
        [object]$Value,
        [string]$Name
    )

    Assert-True -Condition ($Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)) -Message "$Name is required."
}

function Test-AbsolutePathString {
    param([string]$Value)

    return $Value -match '^[A-Za-z]:[\\/]' -or $Value -match '^[\\/]{1,2}'
}

function Assert-NoAbsolutePathStrings {
    param(
        [object]$Value,
        [string]$JsonPath
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [string]) {
        if (Test-AbsolutePathString -Value $Value) {
            throw "Canonical trace contains machine-local absolute path at ${JsonPath}: $Value"
        }
        return
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            Assert-NoAbsolutePathStrings -Value $Value[$key] -JsonPath "$JsonPath.$key"
        }
        return
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $index = 0
        foreach ($item in $Value) {
            Assert-NoAbsolutePathStrings -Value $item -JsonPath "$JsonPath[$index]"
            $index++
        }
        return
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            Assert-NoAbsolutePathStrings -Value $property.Value -JsonPath "$JsonPath.$($property.Name)"
        }
        return
    }

    # Any other scalar (DateTime, numbers, booleans) carries no path content and
    # is a leaf. Without this guard, PowerShell 7's ConvertFrom-Json coerces ISO
    # timestamps to [datetime], whose self-similar .Date/.DateTime properties make
    # the property walk recurse forever.
}

$resolvedTrace = Resolve-RepoPath -Path $TracePath
$resolvedSchema = Resolve-RepoPath -Path $SchemaPath

if (-not (Test-Path -LiteralPath $resolvedTrace -PathType Leaf)) {
    throw "Trace sample '$TracePath' does not exist."
}

if (-not (Test-Path -LiteralPath $resolvedSchema -PathType Leaf)) {
    throw "Schema '$SchemaPath' does not exist."
}

$trace = Get-Content -Raw -LiteralPath $resolvedTrace | ConvertFrom-Json
$schema = Get-Content -Raw -LiteralPath $resolvedSchema | ConvertFrom-Json

Assert-True -Condition ($schema.'$id' -like '*trace-replay-artifact.v1.schema.json') -Message 'Schema $id must identify trace-replay-artifact.v1.'
Assert-True -Condition ($schema.title -eq 'OxForms W005 Trace Replay Artifact v1') -Message 'Unexpected schema title.'
Assert-True -Condition ($trace.schema -eq 'oxforms.trace_replay.v1') -Message "Unexpected trace schema '$($trace.schema)'."
Assert-True -Condition ($trace.schema_version -eq 1) -Message "Unexpected trace schema_version '$($trace.schema_version)'."
Assert-NonEmptyString -Value $trace.trace_id -Name 'trace_id'
Assert-NonEmptyString -Value $trace.bead -Name 'bead'
Assert-True -Condition ($trace.environment.path_policy -eq 'canonical_artifact_paths_are_repo_relative') -Message 'Trace path policy is not the canonical repo-relative policy.'
Assert-True -Condition ($trace.environment.pal.ui_event_schema_version -eq 1) -Message 'PAL UiEvent schema version must be 1 for W005 v1 sample.'
Assert-True -Condition ($trace.environment.pal.input_contract -eq 'crates/oxforms-pal/src/input.rs') -Message 'PAL input contract path must cite crates/oxforms-pal/src/input.rs.'
Assert-NonEmptyString -Value $trace.clean_room.source -Name 'clean_room.source'
Assert-NonEmptyString -Value $trace.clean_room.prohibited -Name 'clean_room.prohibited'
Assert-True -Condition ([string]$trace.clean_room.prohibited -match 'No Office internals') -Message 'clean_room.prohibited must explicitly exclude Office internals.'

Assert-NoAbsolutePathStrings -Value $trace -JsonPath '$'

$rows = @($trace.rows)
Assert-True -Condition ($rows.Count -gt 0) -Message 'Trace must contain at least one row.'

$allowedRowKinds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@(
    'input_script_step',
    'ui_event',
    'routing_decision',
    'reducer_transition',
    'effect_requested',
    'effect_completed',
    'vba_dispatch',
    'lifecycle_pump',
    'invalidation',
    'display_list',
    'render_artifact',
    'oracle_annotation',
    'comparison_annotation',
    'diagnostic'
) | ForEach-Object { [void]$allowedRowKinds.Add($_) }

# 'display_list'/'render_artifact' rows retired with the probe display-list renderer
# (oxforms-rq5.1): rendering is now VBA-authored, so these goldens carry only
# reducer/input/lifecycle/effect/routing rows. Both kinds remain in $allowedRowKinds
# for back-compatibility with any older committed trace, but are no longer required.
$requiredRowKinds = @(
    'input_script_step',
    'ui_event',
    'routing_decision',
    'reducer_transition',
    'effect_requested',
    'effect_completed',
    'vba_dispatch',
    'lifecycle_pump',
    'invalidation'
)

$allowedUiEventSources = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@('pal', 'host_extension', 'service', 'replay', 'oracle') | ForEach-Object { [void]$allowedUiEventSources.Add($_) }

$allowedUiEventKinds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@(
    'mouse_move',
    'mouse_down',
    'mouse_up',
    'mouse_double_click',
    'mouse_wheel',
    'key_down',
    'key_up',
    'character_input',
    'focus_in',
    'focus_out',
    'activate',
    'deactivate',
    'close_request',
    'timer_fired',
    'clipboard_result',
    'drag_over',
    'drop_or_paste',
    'service_result',
    'dpi_changed',
    'resize',
    'host_extension',
    'form_instance_requested',
    'form_loaded',
    'form_load_failed',
    'show_requested',
    'window_shown',
    'hide_requested',
    'window_hidden',
    'query_close_completed',
    'focus_validation_completed',
    'key_down_swallowed',
    'unload_requested',
    'unloaded',
    'terminated',
    'pump_yield_requested',
    'pump_frame_exited'
) | ForEach-Object { [void]$allowedUiEventKinds.Add($_) }

$allowedCoordinateSpaces = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@(
    'screen_pixels',
    'window_rect',
    'screenshot_pixels',
    'client_pixels',
    'form_logical',
    'control_local',
    'display_list_logical',
    'msforms_event_args',
    'raw_diagnostic'
) | ForEach-Object { [void]$allowedCoordinateSpaces.Add($_) }

$rowById = @{}
$kindCounts = @{}
$uiEvents = @{}
$effectRequests = @{}
$dispatches = @{}
$invalidations = @{}
$lastSequence = 0
$coordinateCount = 0

foreach ($row in $rows) {
    Assert-NonEmptyString -Value $row.row_id -Name 'row_id'
    Assert-True -Condition (-not $rowById.ContainsKey($row.row_id)) -Message "Duplicate row_id '$($row.row_id)'."
    Assert-True -Condition ($row.sequence -is [int] -or $row.sequence -is [long]) -Message "Row '$($row.row_id)' sequence must be an integer."
    Assert-True -Condition ($row.sequence -gt $lastSequence) -Message "Row '$($row.row_id)' sequence must increase monotonically."
    Assert-True -Condition ($allowedRowKinds.Contains([string]$row.kind)) -Message "Row '$($row.row_id)' has unsupported kind '$($row.kind)'."

    $parentRowId = Get-PropertyValue -Object $row -Name 'parent_row_id'
    if ($null -eq $parentRowId) {
        Assert-True -Condition ($row.nesting_depth -eq 0) -Message "Top-level row '$($row.row_id)' must have nesting_depth 0."
    }
    else {
        Assert-True -Condition ($rowById.ContainsKey($parentRowId)) -Message "Row '$($row.row_id)' parent '$parentRowId' must be a prior row."
        $parent = $rowById[$parentRowId]
        Assert-True -Condition ($row.nesting_depth -gt $parent.nesting_depth) -Message "Row '$($row.row_id)' nesting_depth must be greater than parent nesting_depth."
    }

    $rowById[$row.row_id] = $row
    $lastSequence = $row.sequence

    if (-not $kindCounts.ContainsKey($row.kind)) {
        $kindCounts[$row.kind] = 0
    }
    $kindCounts[$row.kind]++

    switch ($row.kind) {
        'ui_event' {
            $uiEventId = Get-PropertyValue -Object $row.payload -Name 'ui_event_id'
            Assert-NonEmptyString -Value $uiEventId -Name "ui_event_id for row '$($row.row_id)'"
            Assert-True -Condition (-not $uiEvents.ContainsKey($uiEventId)) -Message "Duplicate ui_event_id '$uiEventId'."
            Assert-True -Condition ($row.payload.ui_event_schema_version -eq $trace.environment.pal.ui_event_schema_version) -Message "UiEvent '$uiEventId' schema version does not match environment PAL schema version."
            Assert-True -Condition ($allowedUiEventSources.Contains([string]$row.payload.source)) -Message "UiEvent '$uiEventId' has unsupported source '$($row.payload.source)'."
            $kind = $row.payload.normalized_input.kind
            Assert-True -Condition ($allowedUiEventKinds.Contains([string]$kind)) -Message "UiEvent '$uiEventId' has unsupported PAL kind '$kind'."
            $uiEvents[$uiEventId] = $row

            $coordinates = @(Get-PropertyValue -Object $row.payload -Name 'coordinates')
            foreach ($coordinate in $coordinates) {
                if ($null -eq $coordinate) {
                    continue
                }
                Assert-True -Condition ($allowedCoordinateSpaces.Contains([string]$coordinate.space)) -Message "UiEvent '$uiEventId' has unsupported coordinate space '$($coordinate.space)'."
                Assert-NonEmptyString -Value $coordinate.unit -Name "coordinate unit for '$uiEventId'"
                Assert-NonEmptyString -Value $coordinate.origin -Name "coordinate origin for '$uiEventId'"
                Assert-NonEmptyString -Value $coordinate.source -Name "coordinate source for '$uiEventId'"
                $coordinateCount++
            }
        }
        'routing_decision' {
            $causalUiEventId = Get-PropertyValue -Object $row.payload -Name 'causal_ui_event_id'
            Assert-True -Condition ($uiEvents.ContainsKey($causalUiEventId)) -Message "Routing row '$($row.row_id)' refers to unknown or later ui_event_id '$causalUiEventId'."
        }
        'reducer_transition' {
            $transitionId = Get-PropertyValue -Object $row.payload -Name 'transition_id'
            Assert-NonEmptyString -Value $transitionId -Name "transition_id for row '$($row.row_id)'"
            $causalUiEventId = Get-PropertyValue -Object $row.payload -Name 'causal_ui_event_id'
            Assert-True -Condition ($uiEvents.ContainsKey($causalUiEventId)) -Message "Transition '$transitionId' refers to unknown or later ui_event_id '$causalUiEventId'."
            Assert-True -Condition ($null -ne (Get-PropertyValue -Object $row.payload -Name 'before')) -Message "Transition '$transitionId' requires before summary."
            Assert-True -Condition ($null -ne (Get-PropertyValue -Object $row.payload -Name 'after')) -Message "Transition '$transitionId' requires after summary."

            $beforePending = Get-PropertyValue -Object $row.payload.before -Name 'pending_effect_count'
            $afterPending = Get-PropertyValue -Object $row.payload.after -Name 'pending_effect_count'
            if ($null -ne $beforePending -and $null -ne $afterPending) {
                Assert-True -Condition ($beforePending -ge 0) -Message "Transition '$transitionId' before.pending_effect_count must be non-negative."
                Assert-True -Condition ($afterPending -ge 0) -Message "Transition '$transitionId' after.pending_effect_count must be non-negative."
            }

            if ($trace.trace_id -eq 'w005-reducer-skeleton-transition-log-v1' -and $transitionId -eq 'transition-0001') {
                $emittedEffectIds = @(Get-PropertyValue -Object $row.payload -Name 'emitted_effect_ids')
                $expectedAfterPending = $beforePending + $emittedEffectIds.Count
                Assert-True -Condition ($beforePending -eq 0) -Message "Reducer skeleton sample transition '$transitionId' must start from a fresh FormState with before.pending_effect_count=0."
                Assert-True -Condition ($afterPending -eq $expectedAfterPending) -Message "Reducer skeleton sample transition '$transitionId' pending_effect_count must increase by emitted_effect_ids count; before=$beforePending emitted=$($emittedEffectIds.Count) after=$afterPending."

                $implementationDiagnostic = @($rows | Where-Object {
                    $_.kind -eq 'ui_event'
                })[0].payload.diagnostics | Where-Object {
                    $_.source -eq 'reducer_skeleton_sample' -and $_.name -eq 'implementation'
                } | Select-Object -First 1
                Assert-True -Condition ($null -ne $implementationDiagnostic) -Message "Reducer skeleton sample must record its implementation source."
                Assert-True -Condition ($implementationDiagnostic.value -eq 'crates/oxforms-core/src/lib.rs') -Message "Reducer skeleton sample must cite crates/oxforms-core/src/lib.rs, not the PAL crate."
            }
        }
        'effect_requested' {
            $effectId = Get-PropertyValue -Object $row.payload -Name 'effect_id'
            Assert-NonEmptyString -Value $effectId -Name "effect_id for row '$($row.row_id)'"
            Assert-True -Condition (-not $effectRequests.ContainsKey($effectId)) -Message "Duplicate effect_id '$effectId'."
            Assert-NonEmptyString -Value $row.payload.effect_kind -Name "effect_kind for effect '$effectId'"
            $effectRequests[$effectId] = $row
        }
        'effect_completed' {
            $effectId = Get-PropertyValue -Object $row.payload -Name 'effect_id'
            Assert-True -Condition ($effectRequests.ContainsKey($effectId)) -Message "Effect completion row '$($row.row_id)' refers to unknown or later effect_id '$effectId'."
        }
        'vba_dispatch' {
            $dispatchId = Get-PropertyValue -Object $row.payload -Name 'dispatch_id'
            Assert-NonEmptyString -Value $dispatchId -Name "dispatch_id for row '$($row.row_id)'"
            Assert-True -Condition (-not $dispatches.ContainsKey($dispatchId)) -Message "Duplicate dispatch_id '$dispatchId'."
            $effectId = Get-PropertyValue -Object $row.payload -Name 'effect_id'
            Assert-True -Condition ($effectRequests.ContainsKey($effectId)) -Message "Dispatch '$dispatchId' refers to unknown or later effect_id '$effectId'."
            Assert-NonEmptyString -Value $row.payload.event_name -Name "event_name for dispatch '$dispatchId'"
            Assert-True -Condition ($row.payload.fact_source.path -eq 'docs/specs/FM20_EVENT_FACTS.md') -Message "Dispatch '$dispatchId' must cite docs/specs/FM20_EVENT_FACTS.md."
            $dispatches[$dispatchId] = $row
        }
        'lifecycle_pump' {
            Assert-NonEmptyString -Value $row.payload.pump_term -Name "pump_term for row '$($row.row_id)'"
            Assert-True -Condition ($null -ne (Get-PropertyValue -Object $row.payload -Name 'modal_depth')) -Message "Lifecycle/pump row '$($row.row_id)' requires modal_depth."
        }
        'invalidation' {
            $invalidationId = Get-PropertyValue -Object $row.payload -Name 'invalidation_id'
            Assert-NonEmptyString -Value $invalidationId -Name "invalidation_id for row '$($row.row_id)'"
            $invalidations[$invalidationId] = $row
            foreach ($region in @($row.payload.regions)) {
                Assert-True -Condition ($allowedCoordinateSpaces.Contains([string]$region.space)) -Message "Invalidation '$invalidationId' has unsupported coordinate space '$($region.space)'."
                Assert-True -Condition ($null -ne (Get-PropertyValue -Object $region -Name 'rect')) -Message "Invalidation '$invalidationId' region requires rect."
                $coordinateCount++
            }
        }
    }
}

foreach ($requiredKind in $requiredRowKinds) {
    Assert-True -Condition ($kindCounts.ContainsKey($requiredKind)) -Message "Trace sample is missing required row kind '$requiredKind'."
}

Assert-True -Condition ($coordinateCount -gt 0) -Message 'Trace sample must include coordinate-space-tagged coordinates or regions.'
Assert-True -Condition ($dispatches.Count -gt 0) -Message 'Trace sample must include at least one VBA dispatch row.'

Write-Host 'Trace replay schema check: ok'
Write-Host "Schema: $SchemaPath"
Write-Host "Trace: $TracePath"
Write-Host "Rows checked: $($rows.Count)"
Write-Host "Coordinate-bearing entries checked: $coordinateCount"
