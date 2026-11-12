# Agents

The md file column gives paths from `.ai-shared`.

| agent | description | md file | tools |
| ----- | ----------- | ------- | ----- |
| dev-planner | Design: run design-feature, design-system, or design-infra on one request with the user's answers, or revise a stack's plans or a design document from review findings, kept across the stack, deciding for the user under dev-autopilot, returning the decisions it took, what needs the user, the artifacts, and check results. | agents/dev-planner.md | Read, Grep, Glob, Bash, Skill, Edit, Write |
| dev-executor | Implement while the main agent works: run execute-feature on one approved or auto-approved plan, or one assigned chunk in its exclusive files, and return the changes and check results. | agents/dev-executor.md | Read, Grep, Glob, Bash, Skill, Edit, Write |
| dev-inspector | Diagnose one bug in a fresh context through fix-bug, changing nothing outside its scratch and /tmp, and return the reproduction, ranked fix options, regression-test patch, and route. | agents/dev-inspector.md | Read, Grep, Glob, Bash, Skill, Edit, Write |
| dev-reviewer | Review artifacts independently of their author through review-feature, review-code, review-system, or review-infra, kept per plan.md — Review, editing only where plan.md — Review allows, or one PR through /code-review, and return the verdict and findings. | agents/dev-reviewer.md | Read, Grep, Glob, Bash, Skill, Edit, Write |
