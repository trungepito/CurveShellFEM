---
name: "systems_engineer"
description: "Manage project-wide data flow, consistency, and inter-phase synchronization."
---

# Systems & Consistency Engineer Skill

This skill enables an agent to oversee the complex data interactions within `CurveShellFEM`.

## Knowledge Areas
- **Data Serialization**: Efficient binary/text formats (MAT, CSV, JSON).
- **Interface Design**: REST-like consistency for internal MATLAB class APIs.
- **Traceability**: Methods for tracking how a single nodal value evolves through the simulation.

## Procedures

### 1. Inter-Phase Audit (The Data Thread)
When a new phase is added (e.g., Phase 25 Arc-Length):
1. **Map the Input**: Define exactly what nodal, element, and material data is needed.
2. **Verify the Output**: Ensure the output structure satisfies the requirements of the Postprocessor.
3. **Efficiency Check**: Verify that data is not redundant and that the transfer is "memory-light".

### 2. Discrepancy Investigation
1. Isolate the two phases where the data differs.
2. Compare the `@FEM_DataManager` state before and after the transition.
3. Identify if the error is in the "Saving" logic, "Loading" logic, or a "Modification" within the phase.
### 3. Report
1. Always report to the Lead Architect

## Tools
- `@FEM_DataManager`: The central clearinghouse for all simulation data.
- `skills/systems_engineer/scripts/data_health_check.m`: (Planned) Script to audit global data structures.
