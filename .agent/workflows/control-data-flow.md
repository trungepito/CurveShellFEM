---
description: "Use when ensuring project-wide consistency in data flow, schemas, and architectural patterns."
---

# Control Data Flow Workflow (Refactored)

## Objective
Ensure that input and output data are consistent across all project phases and that transfers are efficient.

## Steps

1. **Phase Boundary Audit**:
    - Identify the boundary between Phase A and Phase B (e.g., Preprocessor to Solver).
    - Compare the output schema of Phase A with the input requirements of Phase B.

2. **Discrepancy Analysis**:
    - Trace specific data points (e.g., node 100 displacement) through the `save`/`load` cycle.
    - Identify mismatch in precision, units, or indexing.

3. **Persistence Optimization**:
    - Evaluate the size and speed of stored states. 
    - Ensure that "History Variables" are not lost during restart.

4. **API Consistency Check**:
    - Verify that all agents are using the `@FEM_DataManager` API correctly without bypassing it.

## Verification Checklist
- [ ] Phase A output = Phase B input confirmed.
- [ ] No "Shadow Data" (logic that bypasses the DataManager).
- [ ] History variables are correctly restored in "Warm Start" tests.
- [ ] Discrepancy report provided to offending agent and Lead Architect.
