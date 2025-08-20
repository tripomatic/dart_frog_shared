---
description: Implement an issue from github issues
---

## Preparation

- make sure the main branch is up to date, switch to it and sync if needed, otherwise refuse to continue
- load the issue $ARGUMENTS from github issues using `gh` and make sure you read all comments
- research the issue, current code base and understand it
- determine the sub agents to use for information gathering and the actual implementation.
- create a new branch for the issue
- ask the user any clarification questions if needed
- present concise research summary and an implementation plan
- PROMPT THE USER TO CONFIRM
- Do not write any code before the user confirms

## Implementation

- implement the issue
- commit and push the changes
- create a pull request with the changes
- add a link to the pull request in the issue on github
- prefer to use dedicated sub agents for the implementation if possible.

## Code Review
- Review the PR using the code-review agent
- Make sure sub agents have updated their memories, provide them also with relevant feedback from the code-review agent (major points, concise)
- Automatically fix major bugs / issues.
- Concisely summarize all concerns from the code-review agent and highlight what should be addressed
- PROMPT THE USER TO REVIEW THE PULL REQUEST

