#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Stages = @('context','specify','plan','validate','implement','verify','deliver')
$script:Defaults = Join-Path $PSScriptRoot '../assets/workflow'

function Get-SddRoot([string]$Root) {
    (Resolve-Path -LiteralPath $Root).Path
}

function Get-SddPath([string]$Root, [string]$Relative) {
    $base = Get-SddRoot $Root
    $path = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    $comparison = if ([OperatingSystem]::IsWindows()) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $path.StartsWith($base.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw "Path escapes repository: $Relative"
    }
    # Refuse junctions/symlinks in artifacts/runtime paths rather than following them outside Root.
    $current = $path
    while ($current -ne $base -and $current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked path is unsupported: $current" }
        }
        $current = Split-Path $current -Parent
    }
    $path
}

function Assert-SddFeature([string]$Feature) {
    if ($Feature -notmatch '^[0-9]{3,}-[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'Feature must be a safe name such as 002-user-auth.' }
}

function Get-SddJson([string]$Path) {
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Write-SddFile([string]$Path, [string]$Content) {
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $Content, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}

function Get-SddHead([string]$Root) {
    $head = & git -C $Root rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Root must be a Git repository with a commit.' }
    ($head | Out-String).Trim()
}

function Get-SddConfig([string]$Root) {
    $path = Get-SddPath $Root '.sdd-guo/config.json'
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:Defaults 'config.json' }
    $config = Get-SddJson $path
    if ($config.version -ne 1 -or $config.confirmationPoints -isnot [array]) { throw 'Invalid config version/confirmationPoints.' }
    foreach ($stage in $config.confirmationPoints) {
        if ($stage -notin $script:Stages) { throw "Unknown confirmation point: $stage" }
    }
    $config
}

function Get-SddState([string]$Root, [string]$Feature) {
    Assert-SddFeature $Feature
    $base = Get-SddRoot $Root
    $state = Get-SddJson (Get-SddPath $base '.sdd-guo/state.json')
    if ($state -isnot [Collections.IDictionary] -or $state['stages'] -isnot [Collections.IDictionary] -or $state['taskReports'] -isnot [Collections.IDictionary] -or $state['reviewFindings'] -isnot [Collections.IDictionary] -or $state['history'] -isnot [array]) { throw 'Invalid state schema: expected stage/report/finding dictionaries and history array.' }
    if ($state.version -ne 1 -or $state.feature -ne $Feature -or $state.repository -ne $base) { throw 'State version, feature or repository mismatch. Preserve state and choose the correct context.' }
    if ($state.flowId -notmatch '^[a-f0-9]{8}$' -or $state.currentStage -notin @($script:Stages + 'complete') -or $state.status -notin @('active','complete','archived')) { throw 'Invalid state identity/status.' }
    $pending = $false
    foreach ($stage in $script:Stages) {
        if (-not $state.stages.Contains($stage) -or $state.stages[$stage] -isnot [Collections.IDictionary] -or $state.stages[$stage]['status'] -notin @('pending','confirmed')) { throw "Invalid stage state: $stage" }
        if ($state.stages[$stage].status -eq 'pending') { $pending = $true }
        elseif ($pending) { throw 'Corrupt state: confirmed stage after pending stage.' }
    }
    $expected = @($script:Stages | Where-Object { $state.stages[$_].status -eq 'pending' })
    $expectedCurrent = if ($expected.Count) { $expected[0] } else { 'complete' }
    if ($state.currentStage -ne $expectedCurrent -or ($expected.Count -and $state.status -ne 'active') -or (-not $expected.Count -and $state.status -eq 'active')) { throw 'Corrupt state: current stage/status disagrees with confirmations.' }
    $state
}

function Save-SddState([string]$Root, $State, [string]$Event, [string]$Subject) {
    $entry = @{flowId=$State.flowId; event=$Event; subject=$Subject; at=[DateTime]::UtcNow.ToString('o')}
    $State.history = @($State.history) + $entry
    Write-SddFile (Get-SddPath $Root '.sdd-guo/state.json') ($State | ConvertTo-Json -Depth 30)
    # State history is authoritative if appending the supplementary JSONL log is interrupted.
    [IO.File]::AppendAllText((Get-SddPath $Root '.sdd-guo/events.jsonl'), ($entry | ConvertTo-Json -Compress) + "`n", [Text.UTF8Encoding]::new($false))
}

function Initialize-Sdd([string]$Root, [string]$Feature) {
    Assert-SddFeature $Feature
    $base = Get-SddRoot $Root
    $path = Get-SddPath $base '.sdd-guo/state.json'
    if (Test-Path -LiteralPath $path) { throw 'State already exists. Use resume; archive/preserve an old flow explicitly before starting another.' }
    $head = Get-SddHead $base
    $null = Get-SddConfig $base
    $stages = [ordered]@{}
    foreach ($stage in $script:Stages) { $stages[$stage] = @{status='pending'; evidence=''; fingerprint=''} }
    $baselineRequired=Test-Path -LiteralPath (Get-SddPath $base 'specs/baseline')
    $state = @{version=1; feature=$Feature; repository=$base; flowId=[guid]::NewGuid().ToString('N').Substring(0,8); currentStage='context'; status='active'; commit=$head; stages=$stages; history=@(); taskReports=@{}; reviewFindings=@{}; baselineRequired=[bool]$baselineRequired}
    $null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
    Save-SddState $base $state 'initialized' $Feature
    $state
}

function Get-SddHash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}

function Get-SddTasks([string]$Root, [string]$Feature) {
    $path = Get-SddPath $Root "specs/$Feature/tasks.md"
    $text = Get-Content -LiteralPath $path -Raw
    # Ignore fenced examples: they are not executable tasks.
    $text = Remove-SddFences $text
    $rows = @([regex]::Matches($text, '(?m)^- \[([ xX✓→⚠])\] (T[0-9]+)\s+([^\r\n]+)') | ForEach-Object {
        $status = switch ($_.Groups[1].Value) { ' ' {'pending'} '→' {'in_progress'} '⚠' {'blocked'} default {'done'} }
        @{id=$_.Groups[2].Value; status=$status; description=$_.Groups[3].Value}
    })
    if (-not $rows.Count) { throw 'tasks.md contains no supported task rows.' }
    if (@($rows.id | Select-Object -Unique).Count -ne $rows.Count) { throw 'Duplicate task IDs.' }
    if (@($rows | Where-Object status -eq 'in_progress').Count -gt 1) { throw 'More than one task is in progress.' }
    $rows
}

function Remove-SddFences([string]$Text) {
    $inside = $false; $delimiter = ''; $length = 0
    $lines = foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s{0,3}(`{3,}|~{3,})') {
            $fence = $Matches[1]
            if (-not $inside) { $inside=$true; $delimiter=$fence[0]; $length=$fence.Length }
            elseif ($fence[0] -eq $delimiter -and $fence.Length -ge $length -and $line -match '^\s{0,3}(`+|~+)\s*$') { $inside=$false }
            continue
        }
        if (-not $inside) { $line }
    }
    $lines -join "`n"
}

function Get-SddFingerprint([string]$Root, [string]$Feature, [string]$Stage) {
    $files = switch ($Stage) {
        specify { @('spec.md') }
        plan { @('plan.md','tasks.md') }
        validate { @('spec.md','plan.md','tasks.md','validation.md') }
        implement { @('tasks.md') }
        verify { @('verification.md') }
        deliver { @('delivery.md') }
        default { @() }
    }
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $path = Get-SddPath $Root "specs/$Feature/$file"
        if (-not (Test-Path -LiteralPath $path)) { $parts.Add("${file}:MISSING"); continue }
        if ($file -eq 'tasks.md') {
            # Task descriptions/dependencies are plan inputs; progress/checkpoint metadata is mutable.
            $content = (Get-SddTasks $Root $Feature | ForEach-Object { "$($_.id):$($_.description)" }) -join "`n"
        } else { $content = Get-Content -LiteralPath $path -Raw }
        $parts.Add("${file}:$(Get-SddHash $content)")
    }
    $snapshotPath=Get-SddPath $Root "specs/$Feature/baseline-inputs.json"
    if (Test-Path -LiteralPath $snapshotPath) {
        if ($Stage -in @('plan','validate','implement','verify')) {
            foreach ($file in @('baseline-inputs.json','baseline-delta.json')) {
                $path=Get-SddPath $Root "specs/$Feature/$file"
                $hash=if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path).Hash } else { 'MISSING' }
                $parts.Add("${file}:$hash")
            }
        }
        if ($Stage -in @('implement','verify')) {
            foreach ($file in @('spec.md','design.md')) {
                $path=Get-SddPath $Root "specs/baseline/$file"
                $hash=if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path).Hash } else { 'MISSING' }
                $parts.Add("baseline/${file}:$hash")
            }
        }
    }
    if ($Stage -in @('implement','verify')) {
        $files = @(& git -C $Root -c core.quotepath=false ls-files --cached --others --exclude-standard)
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect working files.' }
        foreach ($file in ($files | Sort-Object -Unique)) {
            if ($file -match '^(specs/|\.sdd-guo/)') { continue }
            $path = Get-SddPath $Root $file
            $hash = if (Test-Path -LiteralPath $path -PathType Leaf) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { 'MISSING' }
            $parts.Add("${file}:$hash")
        }
    }
    Get-SddHash ($parts -join "`n")
}

function Test-SddStage([string]$Root, [string]$Feature, [string]$Stage) {
    Assert-SddFeature $Feature
    if ($Stage -notin $script:Stages) { throw "Unknown stage: $Stage" }
    $path = Get-SddPath $Root '.sdd-guo/checks.json'
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:Defaults 'checks.json' }
    $rules = Get-SddJson $path
    $errors = [Collections.Generic.List[string]]::new()
    if ($rules.Contains($Stage)) {
        foreach ($file in $rules[$Stage].Keys) {
            $path = Get-SddPath $Root "specs/$Feature/$file"
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $errors.Add("Missing artifact: $file"); continue }
            $text = Get-Content -LiteralPath $path -Raw
            $visible = Remove-SddFences $text
            foreach ($rule in $rules[$Stage][$file]) {
                $ok = switch ($rule.type) {
                    file_not_empty { -not [string]::IsNullOrWhiteSpace($text) }
                    must_contain_heading { [regex]::IsMatch($visible, $rule.pattern, [Text.RegularExpressions.RegexOptions]::Multiline, [TimeSpan]::FromSeconds(2)) }
                    must_match_regex { [regex]::IsMatch($visible, $rule.pattern, [Text.RegularExpressions.RegexOptions]::Multiline, [TimeSpan]::FromSeconds(2)) }
                    must_not_match_regex { -not [regex]::IsMatch($visible, $rule.pattern, [Text.RegularExpressions.RegexOptions]::Multiline, [TimeSpan]::FromSeconds(2)) }
                    default { throw "Unknown check type: $($rule.type)" }
                }
                if (-not $ok) { $errors.Add("${file}: $($rule.type) failed: $($rule['pattern'])") }
            }
        }
    }
    if ($Stage -eq 'plan') { $null = Get-SddTasks $Root $Feature }
    if ($errors.Count) { throw ($errors -join "`n") }
    "Structural checks passed: $Stage (semantic review still required)"
}

function Get-SddStale($State, [string]$Root, [string]$Feature) {
    foreach ($stage in $script:Stages) {
        if ($State.stages[$stage].status -eq 'confirmed' -and $State.stages[$stage].fingerprint -ne (Get-SddFingerprint $Root $Feature $stage)) { $stage }
    }
}

function Confirm-SddStage([string]$Root, [string]$Feature, [string]$Stage, [string]$Evidence, [string]$Acknowledgement) {
    $state = Get-SddState $Root $Feature
    if ($Stage -ne $state.currentStage -or $Stage -notin $script:Stages) { throw "Cannot skip/reconfirm stages; expected $($state.currentStage)." }
    if ([string]::IsNullOrWhiteSpace($Evidence)) { throw 'Evidence is required; status alone is not acceptance.' }
    $stale = @(Get-SddStale $state $Root $Feature)
    if ($stale.Count) { throw "Stale evidence: $($stale -join ', '). Reopen the earliest affected stage." }
    if ((Get-SddHead $Root) -ne $state.commit) { throw 'HEAD changed. Reopen context and revalidate repository/authority before confirmation.' }
    if ($Stage -in (Get-SddConfig $Root).confirmationPoints -and [string]::IsNullOrWhiteSpace($Acknowledgement)) { throw "Configured confirmation point: $Stage. Record existing user approval; do not invent it." }
    $null = Test-SddStage $Root $Feature $Stage
    $baselineRequired=($state.Contains('baselineRequired') -and $state.baselineRequired) -or (Test-Path -LiteralPath (Get-SddPath $Root "specs/$Feature/baseline-inputs.json"))
    if ($baselineRequired -and $Stage -in @('plan','validate','implement','verify','deliver')) {
        $mode=if ($Stage -in @('implement','verify','deliver')) { 'applied' } else { 'preview' }
        $null=Test-SddBaseline $Root $Feature $mode
    }
    if ($Stage -in @('implement','verify','deliver')) {
        foreach ($task in (Get-SddTasks $Root $Feature)) {
            if ($task.status -ne 'done' -or -not $state.taskReports.Contains($task.id) -or $state.taskReports[$task.id].status -ne 'DONE') { throw "Task $($task.id) is incomplete or has no DONE report." }
        }
    }
    if ($Stage -in @('verify','deliver')) {
        foreach ($finding in $state.reviewFindings.Values) {
            if ($finding.severity -eq 'error' -and -not $finding.resolved) { throw 'Unresolved blocking review finding.' }
        }
    }
    $state.stages[$Stage] = @{status='confirmed'; evidence=$Evidence; acknowledgement=$Acknowledgement; at=[DateTime]::UtcNow.ToString('o'); fingerprint=(Get-SddFingerprint $Root $Feature $Stage)}
    $index = [array]::IndexOf($script:Stages, $Stage)
    $state.currentStage = if ($index -lt 6) { $script:Stages[$index+1] } else { 'complete' }
    if ($state.currentStage -eq 'complete') { $state.status='complete' }
    Save-SddState $Root $state 'stage-confirmed' $Stage
    $state.currentStage
}

function Reopen-SddStage([string]$Root, [string]$Feature, [string]$Stage, [string]$Evidence) {
    $state = Get-SddState $Root $Feature
    if ($state.status -eq 'archived') { throw 'Archived flows are historical records; start a separately preserved new flow.' }
    if ($Stage -notin $script:Stages -or [string]::IsNullOrWhiteSpace($Evidence)) { throw 'A known stage and reason are required.' }
    $index = [array]::IndexOf($script:Stages, $Stage)
    $currentIndex = if ($state.currentStage -eq 'complete') { 7 } else { [array]::IndexOf($script:Stages, $state.currentStage) }
    if ($index -gt $currentIndex) { throw 'Reopen cannot skip forward.' }
    if ((Get-SddHead $Root) -ne $state.commit -and $Stage -ne 'context') { throw 'Changed HEAD requires reopening context.' }
    foreach ($item in $script:Stages[$index..6]) { $state.stages[$item] = @{status='pending'; evidence=''; fingerprint=''} }
    $state.currentStage=$Stage; $state.status='active'; $state.commit=Get-SddHead $Root
    # Reports are retained as history, but no longer authorize DONE after implementation inputs change.
    if ($index -le 4) { $state.taskReports=@{} }
    Save-SddState $Root $state 'stage-reopened' "${Stage}: $Evidence"
}

function Set-SddTask([string]$Root, [string]$Feature, [string]$Id, [string]$Status, [string]$ReportPath) {
    $state = Get-SddState $Root $Feature
    if ($state.currentStage -ne 'implement') { throw 'Task execution requires the implement stage.' }
    if (@(Get-SddStale $state $Root $Feature).Count -or (Get-SddHead $Root) -ne $state.commit) { throw 'Stale implementation inputs. Resume/reopen before executing tasks.' }
    if ($Status -notin @('pending','in_progress','done','blocked')) { throw 'Unknown task status.' }
    $tasks = @(Get-SddTasks $Root $Feature)
    $task = @($tasks | Where-Object id -eq $Id)
    if ($task.Count -ne 1) { throw "Unknown task: $Id" }
    if ($Status -eq 'in_progress' -and @($tasks | Where-Object { $_.status -eq 'in_progress' -and $_.id -ne $Id }).Count) { throw 'Another task is already in progress.' }
    if ($Status -in @('done','blocked')) {
        $report = Get-SddJson (Get-SddPath $Root $ReportPath)
        $expected = if ($Status -eq 'done') { 'DONE' } else { 'BLOCKED' }
        if ($report.taskId -ne $Id -or $report.status -ne $expected -or [string]::IsNullOrWhiteSpace($report.summary)) { throw 'Report task/status/summary mismatch.' }
        if ($Status -eq 'done') {
            if ($report.checks -isnot [array] -or -not $report.checks.Count) { throw 'DONE needs verification evidence.' }
            foreach ($check in $report.checks) {
                if ($check.result -ne 'passed' -or [string]::IsNullOrWhiteSpace($check.evidence)) { throw 'DONE requires every declared check to pass with evidence.' }
            }
        } elseif ([string]::IsNullOrWhiteSpace($report.reason) -or [string]::IsNullOrWhiteSpace($report.resumeHint)) { throw 'BLOCKED needs reason and resumeHint.' }
        $state.taskReports[$Id]=$report
    } else { $null = $state.taskReports.Remove($Id) }
    $path = Get-SddPath $Root "specs/$Feature/tasks.md"
    $text = Get-Content -LiteralPath $path -Raw
    $mark = switch ($Status) { pending {' '} in_progress {'→'} done {'x'} blocked {'⚠'} }
    # Match only real rows outside code fences; preserve all other bytes and newline convention.
    $fenceState=@{inside=$false; character=''; length=0}
    $text = [regex]::Replace($text, '(?m)^.*$', {
        param($match)
        $line=$match.Value
        if ($line -match '^\s{0,3}(`{3,}|~{3,})') {
            $fence=$Matches[1]
            if (-not $fenceState.inside) { $fenceState.inside=$true; $fenceState.character=$fence[0]; $fenceState.length=$fence.Length }
            elseif ($fence[0] -eq $fenceState.character -and $fence.Length -ge $fenceState.length -and $line -match '^\s{0,3}(`+|~+)\s*\r?$') { $fenceState.inside=$false }
        } elseif (-not $fenceState.inside -and $line -match "^- \[[ xX✓→⚠]\] $([regex]::Escape($Id))\s") {
            return [regex]::Replace($line, '^- \[[ xX✓→⚠]\]', "- [$mark]")
        }
        $line
    }.GetNewClosure())
    Write-SddFile $path $text
    Save-SddState $Root $state "task-$Status" $Id
}

function Set-SddFinding([string]$Root, [string]$Feature, [string]$Id, [string]$Evidence, [string]$Severity='warn', [switch]$Resolved) {
    $state = Get-SddState $Root $Feature
    if ([string]::IsNullOrWhiteSpace($Id) -or [string]::IsNullOrWhiteSpace($Evidence) -or $Severity -notin @('info','warn','error')) { throw 'Finding ID, severity and evidence are required.' }
    if ($state.currentStage -notin @('implement','verify','deliver')) { throw 'Findings require an active implementation/review/delivery stage.' }
    $state.reviewFindings[$Id]=@{severity=$Severity; evidence=$Evidence; resolved=[bool]$Resolved; at=[DateTime]::UtcNow.ToString('o')}
    Save-SddState $Root $state 'review-finding' $Id
}

function Get-SddResume([string]$Root, [string]$Feature) {
    $state = Get-SddState $Root $Feature
    $tasks = @()
    if (Test-Path -LiteralPath (Get-SddPath $Root "specs/$Feature/tasks.md")) { $tasks=@(Get-SddTasks $Root $Feature) }
    $next = @($tasks | Where-Object status -eq 'in_progress')
    if (-not $next.Count) { $next=@($tasks | Where-Object status -eq 'pending') }
    $blocked = @($tasks | Where-Object status -eq 'blocked')
    @{flowId=$state.flowId; currentStage=$state.currentStage; status=$state.status; headChanged=((Get-SddHead $Root) -ne $state.commit); staleStages=@(Get-SddStale $state $Root $Feature); nextTask=$(if ($next.Count) { $next[0].id } else { $null }); blockedTasks=@($blocked | ForEach-Object { $_.id }); findings=$state.reviewFindings}
}

function Get-SddOverview([string]$Root, [string]$Feature) {
    $state = Get-SddState $Root $Feature
    "Flow $($state.flowId): $Feature"
    ($script:Stages | ForEach-Object {
        $marker = if ($state.stages[$_].status -eq 'confirmed') { '[x]' } elseif ($_ -eq $state.currentStage) { '[>]' } else { '[ ]' }
        "$marker $_"
    }) -join ' -> '
    "Next: $($state.currentStage). Use resume to inspect freshness and task blockers."
}

function Test-SddDoctor([string]$Root) {
    $base=Get-SddRoot $Root
    $results = [Collections.Generic.List[object]]::new()
    try { $null=Get-SddHead $base; $results.Add(@{check='git'; status='passed'; detail='Repository has HEAD.'}) } catch { $results.Add(@{check='git'; status='failed'; detail=$_.Exception.Message}) }
    try { $null=Get-SddConfig $base; $results.Add(@{check='config'; status='passed'; detail='Valid config/defaults.'}) } catch { $results.Add(@{check='config'; status='failed'; detail=$_.Exception.Message}) }
    $path=Get-SddPath $base '.sdd-guo/state.json'
    if (Test-Path -LiteralPath $path) {
        try { $raw=Get-SddJson $path; $null=Get-SddState $base $raw.feature; $results.Add(@{check='state'; status='passed'; detail='Valid bound state.'}) } catch { $results.Add(@{check='state'; status='failed'; detail=$_.Exception.Message}) }
    }
    $integration=Get-SddPath $base '.specify/integration.json'
    if (Test-Path -LiteralPath $integration) {
        try { $null=Get-SddJson $integration; $results.Add(@{check='spec-kit'; status='optional'; detail='Integration JSON readable; inspect supported commands separately.'}) } catch { $results.Add(@{check='spec-kit'; status='failed'; detail=$_.Exception.Message}) }
    } else { $results.Add(@{check='spec-kit'; status='optional'; detail='Absent; concise equivalent artifacts are supported.'}) }
    foreach ($tool in @('gh','specify')) {
        $available=[bool](Get-Command $tool -ErrorAction SilentlyContinue)
        $results.Add(@{check=$tool; status='optional'; detail=$(if ($available) { 'Available; authentication/permissions not inferred.' } else { 'Absent; GitHub connector/equivalent artifacts may be used.' })})
    }
    $results.ToArray()
}

function Complete-SddArchive([string]$Root, [string]$Feature, [string]$Evidence) {
    $state=Get-SddState $Root $Feature
    if ($state.status -ne 'complete' -or [string]::IsNullOrWhiteSpace($Evidence)) { throw 'Archive requires complete delivery and verified base/merge evidence.' }
    foreach ($file in @('specs/baseline/spec.md','specs/baseline/design.md',"specs/$Feature/ARCHIVED.md")) {
        $path=Get-SddPath $Root $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $path -Raw))) { throw "Missing reviewed archive artifact: $file" }
    }
    $receipt=Get-SddJson (Get-SddPath $Root "specs/$Feature/delivery-receipt.json")
    if ($receipt.method -notin @('direct','merged-pr') -or $receipt.baseCommit -notmatch '^[a-f0-9]{40}$' -or [string]::IsNullOrWhiteSpace($receipt.destination)) { throw 'Archive requires direct/merged-pr receipt, base commit and destination; an open PR is not a baseline.' }
    if (($state.Contains('baselineRequired') -and $state.baselineRequired) -or (Test-Path -LiteralPath (Get-SddPath $Root "specs/$Feature/baseline-inputs.json"))) { $null=Test-SddBaseline $Root $Feature applied }
    $state.status='archived'
    Save-SddState $Root $state 'archived' $Evidence
}

. (Join-Path $PSScriptRoot 'Baseline.ps1')
Export-ModuleMember -Function Initialize-Sdd, Get-SddState, Test-SddStage, Confirm-SddStage, Reopen-SddStage, Set-SddTask, Set-SddFinding, Get-SddResume, Get-SddOverview, Test-SddDoctor, Complete-SddArchive, New-SddBaselineSnapshot, Test-SddBaseline, Sync-SddBaseline
