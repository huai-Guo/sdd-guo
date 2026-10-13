#Requires -Version 7.0
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/Workflow.psm1') -Force -DisableNameChecking
$script:Passed=0; $script:Failed=0
$script:Feature='002-unit-test'
$script:Scratch=Join-Path ([IO.Path]::GetTempPath()) ('sdd-unit-' + [guid]::NewGuid().ToString('N'))

function Assert($Condition, [string]$Message='Assertion failed') { if (-not $Condition) { throw $Message } }
function Reject([scriptblock]$Action, [string]$Pattern) {
    $caught=$null
    try { & $Action | Out-Null } catch { $caught=$_.Exception.Message }
    Assert ($null -ne $caught) 'Expected rejection.'
    Assert ($caught -match $Pattern) "Unexpected rejection: $caught"
}
function Put([string]$Relative, [string]$Text) {
    $path=Join-Path $script:Repo $Relative
    $null=New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}
function Before {
    $script:Repo=Join-Path $script:Scratch ([guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $script:Repo -Force
    & git -C $script:Repo init -q
    & git -C $script:Repo config core.autocrlf false
    Put '.gitignore' ".sdd-guo/`n"
    Put 'code.txt' 'original code'
    & git -C $script:Repo add .
    & git -C $script:Repo -c user.name=Unit -c user.email=unit@example.invalid commit -qm baseline
    Assert ($LASTEXITCODE -eq 0) 'Temporary Git fixture failed.'
    Put "specs/$script:Feature/spec.md" "# Spec`n## User Scenarios & Testing *(mandatory)*`nA user resumes.`n## Requirements *(mandatory)*`nFR-001: Preserve evidence.`n## Success Criteria *(mandatory)*`nSC-001: Verify.`n"
    Put "specs/$script:Feature/plan.md" "# Plan`n## Technical Context`nPowerShell 7.`n## Project Structure`nscripts/`n"
    Put "specs/$script:Feature/tasks.md" "# Tasks`n- [ ] T001 First task`n- [ ] T002 Second task (depends on T001)`n"
    Put "specs/$script:Feature/validation.md" "# Validation`n## Document Chain Consistency`nFR-001 -> T001 -> SC-001; no contradictions.`n## Implementation Decision`nGO`n"
    Initialize-Sdd $script:Repo $script:Feature | Out-Null
}
function Advance([string]$Through) {
    foreach ($stage in @('context','specify','plan','validate','implement','verify','deliver')) {
        Confirm-SddStage $script:Repo $script:Feature $stage 'Inspected unit fixture' | Out-Null
        if ($stage -eq $Through) { break }
    }
}
function Report([string]$Id, [string]$Status='DONE') {
    $report=@{taskId=$Id; status=$Status; summary='Unit fixture observation'; checks=@(@{result='passed'; evidence='Observed fixture output'}); reason='Dependency missing'; resumeHint='Restore dependency and retry'}
    Put "specs/$script:Feature/$Id.json" ($report | ConvertTo-Json -Depth 10)
    "specs/$script:Feature/$Id.json"
}
function Done {
    foreach ($id in @('T001','T002')) {
        Set-SddTask $script:Repo $script:Feature $id done (Report $id)
    }
}
function Case([string]$Name, [scriptblock]$Body) {
    try { Before; & $Body; $script:Passed++; Write-Output "PASS $Name" }
    catch { $script:Failed++; Write-Output "FAIL ${Name}: $($_.Exception.Message)"; Write-Output $_.ScriptStackTrace }
}

try {
    Case 'initialization binds repository/flow and refuses overwrite' {
        $s=Get-SddState $script:Repo $script:Feature
        Assert ($s.currentStage -eq 'context' -and $s.flowId.Length -eq 8)
        Reject { Initialize-Sdd $script:Repo $script:Feature } 'already exists'
        $event=Get-Content (Join-Path $script:Repo '.sdd-guo/events.jsonl') | ConvertFrom-Json
        Assert ($event.flowId -eq $s.flowId)
    }
    Case 'feature mismatch and path traversal preserve original state' {
        $before=Get-Content (Join-Path $script:Repo '.sdd-guo/state.json') -Raw
        Reject { Get-SddState $script:Repo '003-other' } 'mismatch'
        Reject { Initialize-Sdd $script:Repo '../escape' } 'safe name'
        Assert ($before -eq (Get-Content (Join-Path $script:Repo '.sdd-guo/state.json') -Raw))
    }
    Case 'ordered confirmation rejects skipped stage without mutation' {
        Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'expected context'
        Assert ((Get-SddState $script:Repo $script:Feature).currentStage -eq 'context')
    }
    Case 'missing real heading cannot be supplied by fenced example' {
        Put "specs/$script:Feature/spec.md" "## User Scenarios`n## Requirements`n~~~markdown`n## Success Criteria`n~~~`n"
        Reject { Test-SddStage $script:Repo $script:Feature specify } 'Success Criteria'
    }
    Case 'Spec Kit headings with suffixes are supported' {
        Assert ((Test-SddStage $script:Repo $script:Feature specify) -match 'passed')
    }
    Case 'empty plan and duplicate tasks reject' {
        Put "specs/$script:Feature/plan.md" ' '
        Reject { Test-SddStage $script:Repo $script:Feature plan } 'file_not_empty'
        Put "specs/$script:Feature/tasks.md" "- [ ] T001 a`n- [x] T001 b`n"
        Reject { Test-SddStage $script:Repo $script:Feature plan } 'Duplicate'
    }
    Case 'NO-GO cannot enter implementation' {
        Advance plan
        Put "specs/$script:Feature/validation.md" "## Document Chain Consistency`nMissing coverage.`n## Implementation Decision`nNO-GO`n"
        Reject { Confirm-SddStage $script:Repo $script:Feature validate 'evidence' } 'failed'
        Assert ((Get-SddState $script:Repo $script:Feature).currentStage -eq 'validate')
    }
    Case 'unknown check types and escaped rule paths fail closed' {
        Put '.sdd-guo/checks.json' '{"specify":{"spec.md":[{"type":"magic"}]}}'
        Reject { Test-SddStage $script:Repo $script:Feature specify } 'Unknown check'
        Put '.sdd-guo/checks.json' '{"specify":{"../../../outside.md":[{"type":"file_not_empty"}]}}'
        Reject { Test-SddStage $script:Repo $script:Feature specify } 'escapes'
    }
    Case 'opt-in confirmation uses acknowledgement; default is autonomous' {
        Put '.sdd-guo/config.json' '{"version":1,"confirmationPoints":["context"]}'
        Reject { Confirm-SddStage $script:Repo $script:Feature context 'evidence' } 'confirmation point'
        Confirm-SddStage $script:Repo $script:Feature context 'evidence' 'User approved this stage' | Out-Null
        Assert ((Get-SddState $script:Repo $script:Feature).currentStage -eq 'specify')
    }
    Case 'bad configuration and corrupt state are reported by doctor' {
        Put '.sdd-guo/config.json' '{"version":1,"confirmationPoints":["unknown"]}'
        Assert (@(Test-SddDoctor $script:Repo | Where-Object status -eq 'failed').Count -eq 1)
        Put '.sdd-guo/state.json' '{broken'
        Assert (@(Test-SddDoctor $script:Repo | Where-Object status -eq 'failed').Count -eq 2)
    }
    Case 'doctor is read-only and optional tools do not block' {
        $before=Get-Content (Join-Path $script:Repo '.sdd-guo/state.json') -Raw
        $rows=@(Test-SddDoctor $script:Repo)
        Assert (@($rows | Where-Object status -eq 'failed').Count -eq 0)
        Assert ($before -eq (Get-Content (Join-Path $script:Repo '.sdd-guo/state.json') -Raw))
    }
    Case 'state detects inconsistent current stage' {
        $s=Get-SddState $script:Repo $script:Feature
        $s.currentStage='implement'
        Put '.sdd-guo/state.json' ($s | ConvertTo-Json -Depth 20)
        Reject { Get-SddState $script:Repo $script:Feature } 'Corrupt'
    }
    Case 'state rejects malformed collection fields without mutation' {
        $s=Get-SddState $script:Repo $script:Feature
        $s.taskReports='invalid'
        Put '.sdd-guo/state.json' ($s | ConvertTo-Json -Depth 20)
        Reject { Get-SddState $script:Repo $script:Feature } 'schema'
    }
    Case 'single active task, blocked report and recovery' {
        Advance validate
        Set-SddTask $script:Repo $script:Feature T001 in_progress
        Reject { Set-SddTask $script:Repo $script:Feature T002 in_progress } 'already in progress'
        Set-SddTask $script:Repo $script:Feature T001 blocked (Report T001 BLOCKED)
        $resume=Get-SddResume $script:Repo $script:Feature
        Assert ($resume.blockedTasks -contains 'T001' -and $resume.nextTask -eq 'T002')
        Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'incomplete'
        Set-SddTask $script:Repo $script:Feature T001 pending
        Assert ((Get-SddResume $script:Repo $script:Feature).nextTask -eq 'T001')
    }
    Case 'DONE requires passed evidence and matching report ID' {
        Advance validate
        Put "specs/$script:Feature/bad.json" '{"taskId":"T001","status":"DONE","summary":"done","checks":[{"result":"not_run","evidence":"none"}]}'
        Reject { Set-SddTask $script:Repo $script:Feature T001 done "specs/$script:Feature/bad.json" } 'every declared check'
        Reject { Set-SddTask $script:Repo $script:Feature T002 done (Report T001) } 'mismatch'
        Assert ((Get-SddResume $script:Repo $script:Feature).nextTask -eq 'T001')
    }
    Case 'report traversal and missing blocked hints reject without task mutation' {
        Advance validate
        Reject { Set-SddTask $script:Repo $script:Feature T001 done '../outside.json' } 'escapes'
        Put "specs/$script:Feature/bad.json" '{"taskId":"T001","status":"BLOCKED","summary":"blocked","reason":"dependency","resumeHint":""}'
        Reject { Set-SddTask $script:Repo $script:Feature T001 blocked "specs/$script:Feature/bad.json" } 'resumeHint'
        Assert ((Get-SddResume $script:Repo $script:Feature).nextTask -eq 'T001')
    }
    Case 'legacy x/X/checkmark rows read; reportless completion is rejected' {
        Put "specs/$script:Feature/tasks.md" "- [x] T001 first`n- [✓] T002 second`n- [X] T003 third`n"
        Advance validate
        Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'no DONE report'
    }
    Case 'fenced task examples remain unchanged during marking' {
        Put "specs/$script:Feature/tasks.md" "~~~md`n- [ ] T001 example`n~~~`n- [ ] T001 real`n- [ ] T002 second`n"
        Advance validate
        Set-SddTask $script:Repo $script:Feature T001 done (Report T001)
        $text=Get-Content (Join-Path $script:Repo "specs/$script:Feature/tasks.md") -Raw
        Assert ($text -match '\[ \] T001 example' -and $text -match '\[x\] T001 real') $text
    }
    Case 'task progress does not stale plan but changed descriptions do' {
        Advance validate
        Set-SddTask $script:Repo $script:Feature T001 done (Report T001)
        Assert (@((Get-SddResume $script:Repo $script:Feature).staleStages).Count -eq 0)
        Put "specs/$script:Feature/tasks.md" "- [x] T001 new behavior`n- [ ] T002 second`n"
        Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'plan')
        Reject { Set-SddTask $script:Repo $script:Feature T002 in_progress } 'Stale'
    }
    Case 'resume flags changed HEAD and requires reopening context' {
        Advance validate
        Put 'code.txt' 'changed'
        & git -C $script:Repo add code.txt
        & git -C $script:Repo -c user.name=Unit -c user.email=unit@example.invalid commit -qm change
        Assert ((Get-SddResume $script:Repo $script:Feature).headChanged)
        Reject { Reopen-SddStage $script:Repo $script:Feature implement 'changed' } 'context'
        Reopen-SddStage $script:Repo $script:Feature context 'Reinspect changed base'
        Assert (-not (Get-SddResume $script:Repo $script:Feature).headChanged)
    }
    Case 'resume flags document changes and reopen invalidates downstream' {
        Advance validate
        Put "specs/$script:Feature/spec.md" 'changed requirements'
        Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'specify')
        Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'Stale'
        Reopen-SddStage $script:Repo $script:Feature specify 'Requirements changed'
        $s=Get-SddState $script:Repo $script:Feature
        Assert ($s.stages.context.status -eq 'confirmed' -and $s.stages.validate.status -eq 'pending')
    }
    Case 'working code changes invalidate confirmed implementation' {
        Advance validate; Done
        Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
        Put 'code.txt' 'uncommitted change'
        Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'implement')
        Reject { Confirm-SddStage $script:Repo $script:Feature verify 'evidence' } 'Stale'
    }
    Case 'untracked code changes also invalidate implementation' {
        Advance validate; Done
        Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
        Put 'new-code.txt' 'untracked code'
        Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'implement')
    }
    Case 'deleted artifact is stale and cannot confirm downstream' {
        Advance validate
        Remove-Item -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/spec.md")
        Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'specify')
        Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'Stale'
    }
    Case 'all-blocked tasks have no next task and remain blocked' {
        Advance validate
        foreach ($id in @('T001','T002')) { Set-SddTask $script:Repo $script:Feature $id blocked (Report $id BLOCKED) }
        $resume=Get-SddResume $script:Repo $script:Feature
        Assert ($null -eq $resume.nextTask -and $resume.blockedTasks.Count -eq 2)
    }
    Case 'blocking findings stop verification until resolved' {
        Advance validate; Done
        Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
        Put "specs/$script:Feature/verification.md" "## Acceptance Evidence`nPassed local unit checks.`n## Change Review`nInspected.`n"
        Set-SddFinding $script:Repo $script:Feature F001 'Missing requirement' error
        Reject { Confirm-SddStage $script:Repo $script:Feature verify 'evidence' } 'blocking'
        Set-SddFinding $script:Repo $script:Feature F001 'Fixed and inspected' error -Resolved
        Confirm-SddStage $script:Repo $script:Feature verify 'unit evidence' | Out-Null
        Assert ((Get-SddState $script:Repo $script:Feature).currentStage -eq 'deliver')
    }
    Case 'archive needs delivery artifacts and rejects pending PR receipts' {
        Reject { Complete-SddArchive $script:Repo $script:Feature 'merged' } 'complete delivery'
        Advance validate; Done
        Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
        Put "specs/$script:Feature/verification.md" "## Acceptance Evidence`nUnit tests.`n## Change Review`nReviewed.`n"
        Confirm-SddStage $script:Repo $script:Feature verify 'evidence' | Out-Null
        Put "specs/$script:Feature/delivery.md" 'Destination and verified delivery evidence.'
        Confirm-SddStage $script:Repo $script:Feature deliver 'Verified base commit' | Out-Null
        Reject { Complete-SddArchive $script:Repo $script:Feature 'merged' } 'Missing reviewed archive'
        Put 'specs/baseline/spec.md' 'Current reviewed requirements'
        Put 'specs/baseline/design.md' 'Current reviewed design'
        Put "specs/$script:Feature/ARCHIVED.md" 'Reviewed delta merge and destination'
        Put "specs/$script:Feature/delivery-receipt.json" '{"method":"open-pr","baseCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","destination":"repo/main"}'
        Reject { Complete-SddArchive $script:Repo $script:Feature 'merged' } 'open PR'
        Put "specs/$script:Feature/delivery-receipt.json" '{"method":"direct","baseCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","destination":"repo/main"}'
        Complete-SddArchive $script:Repo $script:Feature 'Verified base receipt'
        Assert ((Get-SddState $script:Repo $script:Feature).status -eq 'archived')
        Reject { Reopen-SddStage $script:Repo $script:Feature context 'restart' } 'historical'
    }
    Case 'overview shows flow/stages without modifying progress' {
        $output=(Get-SddOverview $script:Repo $script:Feature) -join "`n"
        Assert ($output -match '\[>\] context' -and $output -match '\[ \] validate')
    }
    . (Join-Path $PSScriptRoot 'baseline-unit-cases.ps1')
} finally {
    # Only remove the uniquely created test directory under the resolved system temp directory.
    $resolved=[IO.Path]::GetFullPath($script:Scratch)
    $tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'sdd-unit-*') { throw 'Unsafe unit cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
Write-Output "Unit tests: $script:Passed passed, $script:Failed failed. No network or end-to-end tests."
if ($script:Failed) { exit 1 }
