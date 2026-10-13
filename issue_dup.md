## `#print axioms` disagrees with the kept theorem body after a duplicate theorem import.

### Description

Two imported modules can declare the same theorem with the same statement, and Lean keeps one copy ([#3668](https://github.com/leanprover/lean4/pull/3668)). Lean keeps the body from the later module in the import order. Since [#13117](https://github.com/leanprover/lean4/pull/13117), `#print axioms` reads the stored axiom data of the earlier module. Thus `#print axioms` can miss a `sorry` in the kept body, or report a `sorry` that the kept body does not use. Lean gives no warning.

### Reproduction

```lean
-- Good.lean
theorem foo : 1 + 1 = 2 := rfl

-- Bad.lean
theorem foo : 1 + 1 = 2 := sorry

-- GoodFirst.lean
import Good
import Bad
#print foo
#print axioms foo

-- BadFirst.lean
import Bad
import Good
#print foo
#print axioms foo
```

```bash
set -e
for m in Good Bad; do LEAN_PATH=. lean +leanprover/lean4:v4.35.0 -o $m.olean $m.lean; done
LEAN_PATH=. lean +leanprover/lean4:v4.35.0 GoodFirst.lean
LEAN_PATH=. lean +leanprover/lean4:v4.35.0 BadFirst.lean
```

Output:

```
-- GoodFirst.lean
@[defeq] theorem foo : 1 + 1 = 2 :=
sorry
'foo' does not depend on any axioms

-- BadFirst.lean
theorem foo : 1 + 1 = 2 :=
rfl
'foo' depends on axioms: [sorryAx]
```

A new theorem `baz := foo` in the importing file gets the same wrong result. The test set also shows the mismatch with an axiom copy of `foo`, and through an import that never mentions `foo`.

### Versions

The mismatch occurs on 4.31.0, 4.33.1, 4.34.1, 4.35.0 and `nightly-2026-10-13`. On 4.28.0-rc1 and 4.29.0-rc4, `#print axioms` agrees with the kept body. #13117 first shipped in v4.30.0-rc1. We did not test 4.30.0.

### Cause

`finalizeImport` replaces the earlier copy of `foo` with the later copy. But `const2ModIdx` uses `insertIfNew`, so it keeps the earlier module. `ExportedAxiomsState.find?` in `Lean/Util/CollectAxioms.lean` uses that module to read the stored axiom data.

### Fix

The open PR [#15556](https://github.com/leanprover/lean4/pull/15556) removes the stored axiom data. With its CI toolchain (`pr-release-15556`), all our tests give results that agree with the kept body, in both import orders. We did not test files that use the module system. These cases can serve as regression tests for #15556.

`#print axioms` and `#print` disagree after duplicate imports.

### A separate question

the merge accepts hand-written theorems, not only generated equation lemmas. If two merged copies use different axioms, must Lean warn?
