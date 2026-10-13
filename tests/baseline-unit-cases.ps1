# Included by run-unit-tests.ps1; each case gets its own temporary repository.
function Base {
    $script:Login="### FR-001: Login`nMUST sign in.`n`n#### Scenario: Existing`nWHEN credentials`nTHEN sign in.`n`n"
    $script:Logout="### FR-002: Logout`nMUST sign out.`n`n"
    $script:Legacy="### FR-003: Legacy`nMUST support legacy.`n`n"
    $script:Runtime="## Runtime`nPowerShell 7.`n`n"
    $script:Storage="## Storage`nJSON.`n"
    Put 'specs/baseline/spec.md' ("# Current`n`n## Requirements`n`n"+$script:Login+$script:Logout+$script:Legacy+"## Notes`nUnmanaged footer exactly.`n")
    Put 'specs/baseline/design.md' ("# Design`n`n"+$script:Runtime+$script:Storage)
    Remove-Item -LiteralPath (Join-Path $script:Repo '.sdd-guo/state.json')
    Initialize-Sdd $script:Repo $script:Feature | Out-Null
    New-SddBaselineSnapshot $script:Repo $script:Feature | Out-Null
}
function Change {
    $delta=@{version=1; feature=$script:Feature; documents=@{
        'spec.md'=@{operations=@(@{type='MODIFIED'; id='FR-001'; before=$script:Login; after=$script:Login.Replace('MUST sign in.','MUST sign in with MFA.')})}
        'design.md'=@{operations=@(@{type='MODIFIED'; id='Runtime'; before=$script:Runtime; after=$script:Runtime.Replace('PowerShell 7.','PowerShell 7 with snapshots.')})}
    }}
    $delta
}
function SaveDelta($Delta) { Put "specs/$script:Feature/baseline-delta.json" ($Delta | ConvertTo-Json -Depth 20) }
function ReadBase([string]$Document) { Get-Content -LiteralPath (Join-Path $script:Repo "specs/baseline/$Document") -Raw }

Case 'baseline preview mixes operations and preserves unaffected content without writes' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations+=@{type='ADDED'; id='FR-004'; afterId='FR-001'; after="### FR-004: Sessions`nMUST expire sessions.`n`n"}
    $delta.documents['spec.md'].operations+=@{type='REMOVED'; id='FR-003'; before=$script:Legacy; reason='Legacy behavior intentionally retired'}
    SaveDelta $delta
    $original=ReadBase spec.md
    $result=Test-SddBaseline $script:Repo $script:Feature
    Assert ((ReadBase spec.md) -ceq $original) 'Preview mutated the baseline.'
    $output=$result.documents['spec.md'].content
    Assert ($output.Contains($script:Logout) -and $output.EndsWith("## Notes`nUnmanaged footer exactly.`n")) 'Untouched block/footer changed.'
    Assert ($output.Contains('MUST sign in with MFA.') -and $output.Contains('### FR-004: Sessions') -and -not $output.Contains('FR-003'))
    Assert (-not (Test-Path (Join-Path $script:Repo "specs/$script:Feature/baseline-sync.json")))
}
Case 'baseline sync applies both documents and a repeat is a no-op' {
    Base; SaveDelta (Change)
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Assert ((ReadBase spec.md).Contains('with MFA'))
    Assert ((ReadBase design.md).Contains('with snapshots'))
    $record=Get-Content -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-sync.json") -Raw
    Assert ((Sync-SddBaseline $script:Repo $script:Feature) -match 'no files changed')
    Assert ($record -ceq (Get-Content -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-sync.json") -Raw))
    Assert ((Test-SddBaseline $script:Repo $script:Feature applied).synchronized)
}
Case 'baseline stale target rejects all writes including other valid documents' {
    Base; SaveDelta (Change)
    Put 'specs/baseline/design.md' "# Design`n## Runtime`nNew independently delivered decision.`n"
    $specBefore=ReadBase spec.md; $designBefore=ReadBase design.md
    Reject { Sync-SddBaseline $script:Repo $script:Feature } 'conflict'
    Assert ((ReadBase spec.md) -ceq $specBefore -and (ReadBase design.md) -ceq $designBefore)
}
Case 'baseline duplicate operations cannot silently override earlier changes' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations+=$delta.documents['spec.md'].operations[0]
    SaveDelta $delta
    Reject { Sync-SddBaseline $script:Repo $script:Feature } 'duplicate'
    Assert ((ReadBase spec.md).Contains('MUST sign in.'))
}
Case 'baseline ADDED collision and missing MODIFIED target reject' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations=@(@{type='ADDED'; id='FR-001'; afterId='FR-002'; after=$script:Login})
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'already exists'
    $delta.documents['spec.md'].operations[0]=@{type='MODIFIED'; id='FR-999'; before=$script:Login; after=$script:Login}
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'Missing delta target'
}
Case 'baseline before block must match complete captured contract' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations[0].before='MUST sign in.'
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'incomplete before'
}
Case 'baseline scenario loss rejects until explicitly declared' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations[0].after="### FR-001: Login`nMUST sign in with MFA.`n`n"
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'scenario loss'
    $delta.documents['spec.md'].operations[0].removedScenarios=@('Existing')
    SaveDelta $delta
    Assert ((Test-SddBaseline $script:Repo $script:Feature).documents['spec.md'].content.Contains('with MFA'))
}
Case 'baseline REMOVED requires reason and cannot empty a document' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations=@(@{type='REMOVED'; id='FR-003'; before=$script:Legacy; reason=''})
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'explicit reason'
    $delta.documents['spec.md'].operations=@(
        @{type='REMOVED'; id='FR-001'; before=$script:Login; reason='retired'},
        @{type='REMOVED'; id='FR-002'; before=$script:Logout; reason='retired'},
        @{type='REMOVED'; id='FR-003'; before=$script:Legacy; reason='retired'}
    )
    SaveDelta $delta
    Reject { Sync-SddBaseline $script:Repo $script:Feature } 'Cannot empty'
    Assert ((ReadBase spec.md).Contains('FR-001'))
}
Case 'baseline both documents must be declared even for no-impact changes' {
    Base; $delta=Change
    $delta.documents['design.md']=@{operations=@(); reason='No design impact; existing runtime decision preserved'}
    SaveDelta $delta
    $original=ReadBase design.md
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Assert ((ReadBase design.md) -ceq $original)
    $delta.documents.Remove('design.md')
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'explicitly cover'
}
Case 'baseline empty operations without reason fail' {
    Base; $delta=Change
    $delta.documents['spec.md']=@{operations=@()}
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'needs a reason'
}
Case 'baseline unchanged declaration needs a sync receipt but never rewrites prose' {
    Base; $delta=Change
    foreach ($document in @('spec.md','design.md')) { $delta.documents[$document]=@{operations=@(); reason='Implementation-only adjustment with no contract/design impact'} }
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature applied } 'not synchronized'
    $before=ReadBase spec.md
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Assert ((ReadBase spec.md) -ceq $before)
    Assert ((Test-SddBaseline $script:Repo $script:Feature applied).synchronized)
}
Case 'baseline snapshots cannot be overwritten or moved to another feature' {
    Base
    Reject { New-SddBaselineSnapshot $script:Repo $script:Feature } 'already exists'
    SaveDelta (Change)
    $path=Join-Path $script:Repo "specs/$script:Feature/baseline-inputs.json"
    $snapshot=Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
    $snapshot.feature='003-other'
    Put "specs/$script:Feature/baseline-inputs.json" ($snapshot | ConvertTo-Json -Depth 20)
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'context'
}
Case 'baseline manifest changed after synchronization is not implicitly reapplied' {
    Base; $delta=Change; SaveDelta $delta
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    $delta.documents['spec.md'].operations[0].after=$script:Login.Replace('MUST sign in.','MUST use a different auth contract.')
    SaveDelta $delta
    Reject { Sync-SddBaseline $script:Repo $script:Feature } 'conflict'
    Assert ((ReadBase spec.md).Contains('with MFA'))
}
Case 'baseline sync receipt cannot authorize a drifted output' {
    Base; SaveDelta (Change)
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Put 'specs/baseline/spec.md' ((ReadBase spec.md).Replace('with MFA','with unrelated rules'))
    Reject { Test-SddBaseline $script:Repo $script:Feature applied } 'conflict'
}
Case 'baseline legacy bullet IDs and stable design section IDs remain supported' {
    Base
    Put 'specs/baseline/spec.md' "# Existing`n## Requirements`n- **BASE-001**: Existing behavior.`n- BASE-002: Preserve me.`n## Notes`nKeep footer.`n"
    Put 'specs/baseline/design.md' "# Design`n## DES-001: Runtime`nPowerShell.`n## DES-002: Storage`nJSON.`n"
    Remove-Item -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-inputs.json")
    New-SddBaselineSnapshot $script:Repo $script:Feature | Out-Null
    $delta=Change
    $delta.documents['spec.md'].operations=@(@{type='MODIFIED'; id='BASE-001'; before="- **BASE-001**: Existing behavior.`n"; after="- **BASE-001**: Improved behavior.`n"})
    $delta.documents['design.md'].operations=@(@{type='MODIFIED'; id='DES-001'; before="## DES-001: Runtime`nPowerShell.`n"; after="## DES-001: Updated runtime`nPowerShell 7.`n"})
    SaveDelta $delta
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Assert ((ReadBase spec.md).Contains('- BASE-002: Preserve me.'))
    Assert ((ReadBase design.md).Contains('## DES-002: Storage'))
}
Case 'baseline fenced requirements are examples rather than ID collisions' {
    Base
    Put 'specs/baseline/spec.md' ((ReadBase spec.md)+"~~~md`n### FR-001: Example only`n~~~`n")
    Remove-Item -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-inputs.json")
    New-SddBaselineSnapshot $script:Repo $script:Feature | Out-Null
    SaveDelta (Change)
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Assert ((ReadBase spec.md).Contains('### FR-001: Example only'))
}
Case 'baseline invalid second-document operation leaves both originals untouched' {
    Base; $delta=Change
    $delta.documents['design.md'].operations[0].id='Missing section'
    SaveDelta $delta
    $original=ReadBase spec.md
    Reject { Sync-SddBaseline $script:Repo $script:Feature } 'Missing delta target'
    Assert ((ReadBase spec.md) -ceq $original)
}
Case 'baseline second write failure rolls back the first document' {
    Base; SaveDelta (Change)
    $before=ReadBase spec.md
    $module=Get-Module Workflow
    & $module {
        $script:BaselineOriginalWriter=(Get-Command Write-SddFile).ScriptBlock
        $script:BaselineFailOnce=$true
        function script:Write-SddFile([string]$Path,[string]$Content) {
            if ($Path.EndsWith('design.md') -and $script:BaselineFailOnce) { $script:BaselineFailOnce=$false; throw 'Injected unit write failure' }
            & $script:BaselineOriginalWriter $Path $Content
        }
    }
    try { Reject { Sync-SddBaseline $script:Repo $script:Feature } 'rolled back' }
    finally { & $module { Set-Item -LiteralPath Function:script:Write-SddFile -Value $script:BaselineOriginalWriter } }
    Assert ((ReadBase spec.md) -ceq $before) 'First file was not restored.'
    Assert (-not (Test-Path (Join-Path $script:Repo "specs/$script:Feature/baseline-sync.json")))
}
Case 'baseline required snapshot and manifest block planning' {
    Base
    Remove-Item -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-inputs.json")
    Advance specify
    Reject { Confirm-SddStage $script:Repo $script:Feature plan 'evidence' } 'baseline-inputs'
    New-SddBaselineSnapshot $script:Repo $script:Feature | Out-Null
    Reject { Confirm-SddStage $script:Repo $script:Feature plan 'evidence' } 'baseline-delta'
    SaveDelta (Change)
    Confirm-SddStage $script:Repo $script:Feature plan 'evidence' | Out-Null
}
Case 'baseline unsynchronized output blocks implementation confirmation' {
    Base; SaveDelta (Change)
    Advance validate; Done
    Reject { Confirm-SddStage $script:Repo $script:Feature implement 'evidence' } 'not synchronized'
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
    Assert ((Get-SddState $script:Repo $script:Feature).currentStage -eq 'verify')
}
Case 'baseline changes invalidate confirmed implementation freshness' {
    Base; SaveDelta (Change); Advance validate; Done
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    Confirm-SddStage $script:Repo $script:Feature implement 'evidence' | Out-Null
    Put 'specs/baseline/design.md' ((ReadBase design.md)+"## Extra`nNew decision.`n")
    Assert ((Get-SddResume $script:Repo $script:Feature).staleStages -contains 'implement')
}
Case 'baseline removal target and ADDED insertion anchor must exist' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations=@(@{type='REMOVED'; id='FR-999'; before='missing'; reason='retired'})
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'Missing delta target'
    $delta.documents['spec.md'].operations=@(@{type='ADDED'; id='FR-004'; afterId='FR-999'; after="### FR-004: New`nMUST be observable.`n"})
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'afterId anchor'
}
Case 'baseline modified block cannot change its stable ID or smuggle unrelated sections' {
    Base; $delta=Change
    $delta.documents['spec.md'].operations[0].after=$script:Login.Replace('FR-001','FR-999')
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'same ID'
    $delta.documents['spec.md'].operations[0].after=$script:Login+"## Unrelated rewrite`nThis is outside the requirement.`n"
    SaveDelta $delta
    Reject { Test-SddBaseline $script:Repo $script:Feature } 'complete block'
}
Case 'baseline input snapshot is portable and contains no workstation path' {
    Base
    $snapshot=Get-Content -LiteralPath (Join-Path $script:Repo "specs/$script:Feature/baseline-inputs.json") -Raw | ConvertFrom-Json -AsHashtable
    Assert (-not $snapshot.Contains('repository'))
    Assert ($snapshot.commit -match '^[a-f0-9]{40}$')
    SaveDelta (Change)
    Assert ((Test-SddBaseline $script:Repo $script:Feature).mode -eq 'preview')
}
Case 'baseline sync evidence survives Git LF/CRLF manifest normalization' {
    Base; SaveDelta (Change)
    Sync-SddBaseline $script:Repo $script:Feature | Out-Null
    $path=Join-Path $script:Repo "specs/$script:Feature/baseline-delta.json"
    $text=(Get-Content -LiteralPath $path -Raw).Replace("`r`n","`n")
    Put "specs/$script:Feature/baseline-delta.json" ($text.Replace("`n","`r`n"))
    Assert ((Sync-SddBaseline $script:Repo $script:Feature) -match 'no files changed')
    Assert ((Test-SddBaseline $script:Repo $script:Feature applied).synchronized)
}
