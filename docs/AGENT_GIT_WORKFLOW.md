# Agent Workflow Guide: Git-Based Phase Control

To ensure traceability and robust development, all project progress is managed via **Git version control**, with each developmental phase corresponding to a distinct version.

## 1. Responsibilities of the Agent
The AI Agent must follow this lifecycle for every task/phase:

### Step A: Setup & Analysis
1.  **Draft Implementation Plan**: Create `implementation_plan.md` and get user approval.
2.  **Update Task List**: Mark the current phase as `[/]` (in progress) in `task.md`.

### Step B: Execution & Verification
1.  **Develop & Test**: Implement the features and run all benchmarks.
2.  **Verify**: Ensure all unit tests pass.

### Step C: Phase Completion (Branch & Commit)
1.  **Stage All Changes**: Add all modified and new files to the staging area.
2.  **Commit Phase milestone**: Use a descriptive commit message following the format:
    `[Phase XX] Description of major achievements`
3.  **Finalize Artifacts**: Update `walkthrough.md` and `task.md` (marked as `[x]`).

## 2. Recommended Git CLI Path
The agent identified the Git path at:
`C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git\cmd\git.exe`

### Common Commands:
- **Check Status**: `git status`
- **Add Changes**: `git add .`
- **Commit Phase**: `git commit -m "[Phase XX] Complete"`
- **List Versions**: `git log --oneline`

## 3. Best Practices
- **Never bypass verification**: No commit should be made with failing benchmarks.
- **Granular commits**: While the "Phase" is the version, the agent can make intermediate commits if the work is exceptionally complex.
- **Ignore noise**: Ensure `.gitignore` is updated to exclude `tmp/`, artifacts, and MATLAB `*.asv` files.
