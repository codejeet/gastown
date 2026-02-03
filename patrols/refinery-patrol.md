# Refinery Patrol

The Refinery runs this patrol loop on every heartbeat.

## Steps

### 1. Preflight Check
```bash
# Clean up workspace
git status --short

# Ensure we're on the merge queue branch
git checkout main
git pull origin main
```

### 2. Check Merge Queue
```bash
# Look for beads in 'review' or 'mr-ready' status
cat $GT_HOME/beads/beads.jsonl | grep '"status":"review"' | head -5
```

If no MRs pending, skip to step 6.

### 3. Process ONE MR
For each MR (one at a time):

1. Get bead details
2. Find the associated branch
3. Attempt merge:
   ```bash
   git merge --no-ff feature-branch -m "Merge: <bead-title>"
   ```

### 4. Handle Conflicts
If merge conflicts exist:
1. Analyze the conflicts
2. If resolvable (simple conflicts), resolve intelligently
3. If complex, escalate to Mayor with details
4. Update bead status to 'blocked' if escalating

### 5. Validate & Commit
```bash
# Run validation if configured
npm test 2>/dev/null || yarn test 2>/dev/null || echo "No tests configured"

# If tests pass, push
git push origin main
```

Update bead status:
```bash
gt complete <bead-id> refinery
```

### 6. Report Status
```bash
gt activity 5
```

Log completion:
```bash
echo "Refinery patrol complete. MRs processed: N"
```

## Backoff

If no work found for 3 consecutive patrols, increase sleep time:
- 1st empty: normal interval
- 2nd empty: 2x interval
- 3rd+ empty: 4x interval (max)

Reset backoff when work is found.

## Escalation

Escalate to Mayor when:
- Complex merge conflicts
- Test failures
- Bead dependencies unmet
- Worker timeout (processing > 10 minutes)
