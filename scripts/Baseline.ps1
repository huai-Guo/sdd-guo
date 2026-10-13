# Loaded inside Workflow.psm1; uses its path, JSON, hashing and atomic-write helpers.

function ConvertTo-SddBaselineText([string]$Text) { $Text.Replace("`r`n", "`n") }

function Get-SddBaselineBlocks([string]$Text, [string]$Document) {
    # Offsets always refer to the original normalized text, including fenced examples.
    $visible = $Text.ToCharArray()
    $inside=$false; $character=''; $length=0
    foreach ($line in [regex]::Matches($Text, '(?m)^[^\n]*(?:\n|$)')) {
        if ($line.Value -match '^\s{0,3}(`{3,}|~{3,})') {
            $fence=$Matches[1]
            if (-not $inside) { $inside=$true; $character=$fence[0]; $length=$fence.Length }
            elseif ($fence[0] -eq $character -and $fence.Length -ge $length -and $line.Value -match '^\s{0,3}(`+|~+)\s*$') { $inside=$false }
            for ($i=$line.Index; $i -lt $line.Index+$line.Length; $i++) { if ($visible[$i] -ne "`n") { $visible[$i]=' ' } }
            continue
        }
        if ($inside) { for ($i=$line.Index; $i -lt $line.Index+$line.Length; $i++) { if ($visible[$i] -ne "`n") { $visible[$i]=' ' } } }
    }
    $masked=-join $visible
    $pattern=if ($Document -eq 'spec.md') {
        '(?m)^(?:- \*{0,2}(?<id>[A-Z][A-Z0-9]*-[0-9]{3,})\*{0,2}\s*:|### (?:Requirement: )?(?<id>[A-Z][A-Z0-9]*-[0-9]{3,})(?=[:\s]|$))[^\n]*'
    } else { '(?m)^## (?<id>[^\n]+)' }
    $blockMatches=@([regex]::Matches($masked, $pattern))
    $blocks=[Collections.Generic.List[object]]::new()
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($i=0; $i -lt $blockMatches.Count; $i++) {
        $match=$blockMatches[$i]; $id=$match.Groups['id'].Value.Trim()
        if ($Document -eq 'design.md' -and $id -match '^([A-Z][A-Z0-9]*-[0-9]{3,})(?=[:\s]|$)') { $id=$Matches[1] }
        if (-not $seen.Add($id)) { throw "Duplicate baseline ID in ${Document}: $id" }
        $end=if ($i+1 -lt $blockMatches.Count) { $blockMatches[$i+1].Index } else { $Text.Length }
        $levels=if ($Document -eq 'spec.md') { 3 } else { 2 }
        $boundary=[regex]::Match($masked.Substring($match.Index+$match.Length, $end-$match.Index-$match.Length), "(?m)^#{1,$levels} ")
        if ($boundary.Success) { $end=$match.Index+$match.Length+$boundary.Index }
        $blocks.Add(@{id=$id; start=$match.Index; length=$end-$match.Index; text=$Text.Substring($match.Index, $end-$match.Index)})
    }
    $blocks.ToArray()
}

function Get-SddBaselineSnapshot([string]$Root, [string]$Feature) {
    Assert-SddFeature $Feature
    $snapshot=Get-SddJson (Get-SddPath $Root "specs/$Feature/baseline-inputs.json")
    if ($snapshot.version -ne 1 -or $snapshot.feature -ne $Feature -or $snapshot.commit -notmatch '^[a-f0-9]{40}$') { throw 'Baseline snapshot context/schema mismatch.' }
    foreach ($document in @('spec.md','design.md')) {
        $entry=$snapshot.documents[$document]
        if ([string]::IsNullOrWhiteSpace($entry.content) -or $entry.hash -ne (Get-SddHash $entry.content)) { throw "Invalid baseline snapshot content/hash: $document" }
        if (@(Get-SddBaselineBlocks $entry.content $document).Count -eq 0) { throw "No managed baseline blocks: $document. Inspect/migrate the authored format explicitly." }
    }
    $snapshot
}

function New-SddBaselineSnapshot([string]$Root, [string]$Feature) {
    Assert-SddFeature $Feature
    $path=Get-SddPath $Root "specs/$Feature/baseline-inputs.json"
    if (Test-Path -LiteralPath $path) { throw 'Baseline snapshot already exists. Preserve the original; rebase/regenerate explicitly for changed inputs.' }
    $documents=@{}
    foreach ($document in @('spec.md','design.md')) {
        $source=Get-SddPath $Root "specs/baseline/$document"
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing established baseline: $document. Bootstrap deliberately or use a no-baseline flow." }
        $content=ConvertTo-SddBaselineText (Get-Content -LiteralPath $source -Raw)
        if (@(Get-SddBaselineBlocks $content $document).Count -eq 0) { throw "No managed baseline blocks: $document. Inspect/migrate the authored format explicitly." }
        $documents[$document]=@{content=$content; hash=Get-SddHash $content}
    }
    # Reviewable snapshots travel with the branch; only ignored runtime state is path-bound.
    $snapshot=@{version=1; feature=$Feature; commit=Get-SddHead $Root; documents=$documents}
    $null=New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
    Write-SddFile $path ($snapshot | ConvertTo-Json -Depth 20)
    'Baseline inputs captured; author baseline-delta.json before planning confirmation.'
}

function Get-SddBaselineProposal([string]$Root, [string]$Feature) {
    $snapshot=Get-SddBaselineSnapshot $Root $Feature
    $path=Get-SddPath $Root "specs/$Feature/baseline-delta.json"
    $deltaText=ConvertTo-SddBaselineText (Get-Content -LiteralPath $path -Raw)
    $delta=$deltaText | ConvertFrom-Json -AsHashtable
    if ($delta.version -ne 1 -or $delta.feature -ne $Feature -or $delta.documents -isnot [Collections.IDictionary] -or $delta.documents.Count -ne 2 -or -not $delta.documents.Contains('spec.md') -or -not $delta.documents.Contains('design.md')) { throw 'Delta must match feature/version and explicitly cover spec.md and design.md.' }
    $outputs=@{}
    foreach ($document in @('spec.md','design.md')) {
        $declaration=$delta.documents[$document]
        if ($declaration.operations -isnot [array]) { throw "Delta operations must be an array: $document" }
        if (-not $declaration.operations.Count -and [string]::IsNullOrWhiteSpace($declaration['reason'])) { throw "Unchanged baseline document needs a reason: $document" }
        $content=$snapshot.documents[$document].content
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($operation in $declaration.operations) {
            if ($operation.type -cnotin @('ADDED','MODIFIED','REMOVED') -or [string]::IsNullOrWhiteSpace($operation.id) -or -not $seen.Add($operation.id)) { throw "Unknown/duplicate delta operation: $document" }
            $blocks=@(Get-SddBaselineBlocks $content $document)
            $target=@($blocks | Where-Object { $_.id -ceq $operation.id })
            if ($operation.type -eq 'ADDED') {
                if ($target.Count) { throw "ADDED ID already exists: $($operation.id)" }
                $after=ConvertTo-SddBaselineText $operation.after
                $newBlocks=@(Get-SddBaselineBlocks $after $document)
                if ($newBlocks.Count -ne 1 -or $newBlocks[0].id -cne $operation.id -or $newBlocks[0].start -ne 0 -or $newBlocks[0].length -ne $after.Length) { throw 'ADDED must contain exactly its declared complete block.' }
                if (-not $after.EndsWith("`n")) { $after+="`n" }
                $anchor=@($blocks | Where-Object { $_.id -ceq $operation.afterId })
                if ($anchor.Count -ne 1) { throw "Missing ADDED afterId anchor: $($operation.afterId)" }
                $offset=$anchor[0].start+$anchor[0].length
                $content=$content.Insert($offset, $after)
            } else {
                if ($target.Count -ne 1) { throw "Missing delta target: $($operation.id)" }
                $before=ConvertTo-SddBaselineText $operation.before
                if ($before -cne $target[0].text) { throw "Stale/incomplete before block: $($operation.id)" }
                if ($operation.type -eq 'REMOVED') {
                    if ([string]::IsNullOrWhiteSpace($operation.reason)) { throw 'REMOVED needs an explicit reason.' }
                    if (-not [string]::IsNullOrEmpty($operation['after'])) { throw 'REMOVED cannot supply replacement content.' }
                    $after=''
                } else {
                    $after=ConvertTo-SddBaselineText $operation.after
                    $newBlocks=@(Get-SddBaselineBlocks $after $document)
                    if ($newBlocks.Count -ne 1 -or $newBlocks[0].id -cne $operation.id -or $newBlocks[0].start -ne 0 -or $newBlocks[0].length -ne $after.Length) { throw 'MODIFIED must contain exactly its declared complete block with the same ID.' }
                    $oldScenarios=@([regex]::Matches((Remove-SddFences $before), '(?m)^#### Scenario: (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
                    $newScenarios=@([regex]::Matches((Remove-SddFences $after), '(?m)^#### Scenario: (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
                    $removed=@($oldScenarios | Where-Object { $_ -cnotin $newScenarios })
                    if ($operation.Contains('removedScenarios') -and $operation.removedScenarios -isnot [array]) { throw 'removedScenarios must be an array.' }
                    foreach ($scenario in $removed) {
                        if (-not $operation.Contains('removedScenarios') -or $scenario -cnotin $operation.removedScenarios) { throw "Undeclared scenario loss: $scenario" }
                    }
                    if (-not $after.EndsWith("`n")) { $after+="`n" }
                }
                $content=$content.Remove($target[0].start, $target[0].length).Insert($target[0].start, $after)
            }
        }
        if (@(Get-SddBaselineBlocks $content $document).Count -eq 0) { throw "Cannot empty a baseline document: $document. Capability retirement requires a separate scoped decision." }
        $outputs[$document]=@{content=$content; hash=Get-SddHash $content}
    }
    @{snapshot=$snapshot; deltaHash=Get-SddHash $deltaText; documents=$outputs}
}

function Get-SddBaselineCurrent([string]$Root) {
    $documents=@{}
    foreach ($document in @('spec.md','design.md')) {
        $path=Get-SddPath $Root "specs/baseline/$document"
        $content=ConvertTo-SddBaselineText (Get-Content -LiteralPath $path -Raw)
        $documents[$document]=@{content=$content; hash=Get-SddHash $content}
    }
    $documents
}

function Test-SddBaseline([string]$Root, [string]$Feature, [ValidateSet('preview','applied')][string]$Mode='preview') {
    $proposal=Get-SddBaselineProposal $Root $Feature
    $current=Get-SddBaselineCurrent $Root
    $recordPath=Get-SddPath $Root "specs/$Feature/baseline-sync.json"
    $record=$null
    if (Test-Path -LiteralPath $recordPath) { $record=Get-SddJson $recordPath }
    $allOriginal=$true; $allOutput=$true
    foreach ($document in @('spec.md','design.md')) {
        if ($current[$document].hash -cne $proposal.snapshot.documents[$document].hash) { $allOriginal=$false }
        if ($current[$document].hash -cne $proposal.documents[$document].hash) { $allOutput=$false }
    }
    $hasReceipt=$null -ne $record -and $record.version -eq 1 -and $record.feature -eq $Feature -and $record.deltaHash -ceq $proposal.deltaHash
    if ($hasReceipt) {
        foreach ($document in @('spec.md','design.md')) {
            if ($record.documents[$document].beforeHash -cne $proposal.snapshot.documents[$document].hash -or $record.documents[$document].afterHash -cne $proposal.documents[$document].hash) { $hasReceipt=$false }
        }
    }
    if (-not $allOriginal -and -not ($allOutput -and $hasReceipt)) { throw 'Baseline conflict: current content differs from captured inputs or this recorded sync. Preserve changes and rebase the delta.' }
    if ($Mode -eq 'applied' -and (-not $allOutput -or -not $hasReceipt)) { throw 'Baseline is not synchronized; run baseline-sync before verification/delivery.' }
    @{mode=$Mode; synchronized=($allOutput -and $hasReceipt); deltaHash=$proposal.deltaHash; documents=$proposal.documents}
}

function Sync-SddBaseline([string]$Root, [string]$Feature) {
    $checked=Test-SddBaseline $Root $Feature preview
    if ($checked.synchronized) { return 'Baseline already synchronized; no files changed.' }
    $proposal=Get-SddBaselineProposal $Root $Feature
    $current=Get-SddBaselineCurrent $Root
    # Recheck every input immediately before mutation, after full proposal construction.
    foreach ($document in @('spec.md','design.md')) {
        if ($current[$document].hash -cne $proposal.snapshot.documents[$document].hash) { throw 'Baseline changed during synchronization preflight; no files changed.' }
    }
    $recordPath=Get-SddPath $Root "specs/$Feature/baseline-sync.json"
    $recordBefore=if (Test-Path -LiteralPath $recordPath) { Get-Content -LiteralPath $recordPath -Raw } else { $null }
    $written=[Collections.Generic.List[string]]::new()
    try {
        foreach ($document in @('spec.md','design.md')) {
            if ($current[$document].hash -ceq $proposal.documents[$document].hash) { continue }
            $path=Get-SddPath $Root "specs/baseline/$document"
            # Last-moment comparison also catches intervening single-writer edits.
            $now=ConvertTo-SddBaselineText (Get-Content -LiteralPath $path -Raw)
            if ((Get-SddHash $now) -cne $current[$document].hash) { throw "Baseline changed before write: $document" }
            Write-SddFile $path $proposal.documents[$document].content
            $written.Add($document)
        }
        $documents=@{}
        foreach ($document in @('spec.md','design.md')) { $documents[$document]=@{beforeHash=$proposal.snapshot.documents[$document].hash; afterHash=$proposal.documents[$document].hash} }
        $record=@{version=1; feature=$Feature; deltaHash=$proposal.deltaHash; documents=$documents}
        Write-SddFile $recordPath ($record | ConvertTo-Json -Depth 10)
    } catch {
        $failure=$_.Exception.Message
        foreach ($document in $written) {
            $path=Get-SddPath $Root "specs/baseline/$document"
            $now=ConvertTo-SddBaselineText (Get-Content -LiteralPath $path -Raw)
            if ((Get-SddHash $now) -cne $proposal.documents[$document].hash) { throw "Sync failed ($failure); intervening edit in $document preserved. Inspect the partial synchronization manually." }
            Write-SddFile $path $current[$document].content
        }
        # The sync record is written last. Atomic replacement leaves an old record intact on failure.
        if ($null -ne $recordBefore -and (Get-Content -LiteralPath $recordPath -Raw) -cne $recordBefore) { Write-SddFile $recordPath $recordBefore }
        throw "Baseline synchronization failed and writes rolled back: $failure"
    }
    'Baseline synchronized in the working branch. Review and commit it with implementation; archive only after base delivery.'
}
