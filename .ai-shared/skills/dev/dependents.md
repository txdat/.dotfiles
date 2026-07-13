# Dependent Verification — Single Source

Referenced by execute-feature and fix-bug whenever a symbol is removed or its behavior/signature changes.

## Procedure

1. Resolve the symbol's concrete definition and actual visibility: private/file-local, internal export, package-visible, or published API.
2. Prefer LSP find-references/call hierarchy. Exclude tests by path segment or filename suffix, never a broad substring filter.
3. Without semantic tooling, search production files:
   ```bash
   rg -n '<symbol>' . -g '!**/{test,tests,spec,specs,__tests__}/**' \
     -g '!**/*_test.*' -g '!**/*_spec.*' -g '!**/*.test.*' -g '!**/*.spec.*'
   ```
4. Classify every match. Exclude the declaration itself, comments, documentation, and self-references that cannot call the symbol from outside its definition. Text search is evidence, not proof.
5. Check dynamic reachability appropriate to the stack: framework registration, dependency injection, routes, serialization, reflection, templates, generated registries, and configuration. Unresolved dynamic reachability is not `none`.
6. Check published boundaries: package manifests/entry points, public headers/modules, semver-published artifacts, and OpenAPI/proto/GraphQL contracts. Language-level `export`/`public` alone does not prove publication.

## Evidence

```text
Dependents: <symbol>
  Definition: <file:line>
  Visibility: private/file-local | internal export | package-visible | published API
  Repository callers: none | <file:line> — <caller>
  Dynamic reachability: none | <registration/config/hook> | unresolved
  Published-API evidence: n/a | <manifest/entry point/contract>
  Compatibility: unchanged | <breakage>
```

The calling skill owns the verdict. Never claim `none`, safe removal, or compatibility until every applicable evidence field is resolved.
