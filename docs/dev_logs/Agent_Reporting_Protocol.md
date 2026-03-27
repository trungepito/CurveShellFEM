# Agent Reporting & Logging Protocol (v1.0)

To ensure architectural transparency and maintain a robust audit trail, all specialized agents in the `CurveShellFEM` ecosystem MUST follow this protocol for every assigned task.

## 1. Task Initiation (Logging)
As soon as a task is assigned and started, the agent must record the event in their respective development log:
- **Path**: `docs/dev_logs/logs/[phase]_[date]_[AgentName]_logs.md`
- **Format**: `- **YYYY-MM-DD**: Starting task: [Task Name] (e.g., Phase 10 Unification).`
- **example**: `docs/dev_logs/logs/Phase10_2026-03-27_FEM_Expert_Analyst_logs.md`

## 2. Task Completion (Reporting)
Upon finishing the technical work (implementation, analysis, or validation), the agent MUST generate a formal technical report.

- **Path**: `docs/dev_logs/reports/[Phase]_[Agent]_[Topic].md`
- **Naming Convention**: Use the phase number, agent shorthand, and a 2-3 word topic descriptor.
  - *Example*: `Phase10_Validator_RegressionTests.md`

### Report Structure:
1.  **Header**:
    - **Agent**: [Full Agent Name]
    - **Date**: [YYYY-MM-DD]
    - **Subject**: [Topic]
    - **Phase**: [Phase Number]
2.  **Objective**: Brief description of what the task aimed to achieve.
3.  **Implementation / Analysis / Results**: The core technical findings or description of changes.
4.  **Verification**: (Mandatory for Implementers/Validators) Evidence of numerical correctness or benchmark passes.
5.  **Conclusion**: Final assessment and status (PASS/FAIL/COMPLETE).

## 3. Lead Architect Notification
The agent must ensure the Lead Architect is aware of the report path. This is typically done by updating the task status in the conversation or artifact.

## 4. Enforcement
The **Lead Architect** is responsible for auditing these reports before officially closing a phase in the `PROJECT_ROADMAP.md`. Any task finished without a corresponding report is considered **INCOMPLETE**.
