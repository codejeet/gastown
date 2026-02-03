# Witness Patrol

The Witness runs this patrol loop on every heartbeat. Your job is observation and intervention, not execution.

## Steps

### 1. Check Polecat Health
```bash
# List active polecats from hooks
cat $GT_HOME/beads/hooks.jsonl | grep 'polecat' | grep '"status":"pending"'
```

For each active polecat:
1. Check last activity time
2. If no activity > 5 minutes, flag as potentially stuck
3. If no activity > 10 minutes, nudge them:
   ```bash
   gt nudge polecat-N
   ```

### 2. Check Refinery Health
```bash
# Check refinery hook
gt hook refinery
```

If Refinery has pending work but no recent activity:
```bash
gt nudge refinery
```

### 3. Check Merge Queue Depth
```bash
# Count pending MRs
cat $GT_HOME/beads/beads.jsonl | grep '"status":"review"' | wc -l
```

If queue depth > 10:
- Log warning to activity feed
- Consider spawning additional refinery capacity (escalate to Mayor)

### 4. Identify Stuck Workers
Criteria for "stuck":
- Hook assigned > 10 minutes ago
- No progress in bead status
- No recent activity log entries

Actions:
1. First stuck detection: Nudge worker
2. Second stuck detection: Hard restart worker session
3. Third stuck detection: Escalate to Mayor, reassign bead

### 5. Run Rig Plugins
```bash
# Check for rig-level plugin scripts
ls $GT_HOME/../plugins/rig-*.sh 2>/dev/null
```

Execute each plugin script if found.

### 6. Update Activity Feed
```bash
# Log patrol completion
echo "Witness patrol complete. Workers: OK/STUCK. Queue depth: N"
```

## Metrics to Track

- Active workers count
- Stuck workers count
- MR queue depth
- Average MR processing time
- Escalation count

## Escalation

Report to Mayor when:
- Worker stuck 3+ times consecutively
- Merge queue depth > 10
- Plugin failures
- Unexpected worker crashes
