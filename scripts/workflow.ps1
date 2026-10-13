#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('init','check','confirm','reopen','resume','task','finding','overview','doctor','archive','baseline-snapshot','baseline-check','baseline-sync')][string]$Action,
    [string]$Root = (Get-Location).Path,
    [string]$Feature,
    [string]$Stage,
    [string]$Evidence,
    [string]$Acknowledgement,
    [string]$Id,
    [ValidateSet('pending','in_progress','done','blocked')][string]$Status,
    [string]$ReportPath,
    [ValidateSet('info','warn','error')][string]$Severity = 'warn',
    [switch]$Resolved,
    [ValidateSet('preview','applied')][string]$Mode='preview'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workflow.psm1') -Force -DisableNameChecking
try {
    $arguments = @{ Root = $Root; Feature = $Feature }
    switch ($Action) {
        init { Initialize-Sdd @arguments }
        check { Test-SddStage @arguments -Stage $Stage }
        confirm { Confirm-SddStage @arguments -Stage $Stage -Evidence $Evidence -Acknowledgement $Acknowledgement }
        reopen { Reopen-SddStage @arguments -Stage $Stage -Evidence $Evidence }
        resume { Get-SddResume @arguments }
        task { Set-SddTask @arguments -Id $Id -Status $Status -ReportPath $ReportPath }
        finding { Set-SddFinding @arguments -Id $Id -Evidence $Evidence -Severity $Severity -Resolved:$Resolved }
        overview { Get-SddOverview @arguments }
        doctor { Test-SddDoctor -Root $Root }
        archive { Complete-SddArchive @arguments -Evidence $Evidence }
        baseline-snapshot { New-SddBaselineSnapshot @arguments }
        baseline-check { Test-SddBaseline @arguments -Mode $Mode }
        baseline-sync { Sync-SddBaseline @arguments }
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
