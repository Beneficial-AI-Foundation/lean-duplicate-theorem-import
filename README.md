# Duplicate theorems across imports

This project tests a Lean behavior. Two imported modules can declare the same theorem `foo`, one with a real proof and one proved with `sorry`. Lean accepts both imports without an error and keeps only one copy. On the tested versions from 4.31.0 to `nightly-2026-10-13`, `#print axioms` does not describe the copy that Lean keeps. The import order decides which copy Lean keeps and what `#print axioms` reports.

## Layout

Each directory in `cases/` holds four files. `Good.lean` and `Bad.lean` both declare `foo`. `GoodFirst.lean` imports `Good` then `Bad`, and `BadFirst.lean` imports them in the other order.

| Case | `Good.lean` | `Bad.lean` |
|---|---|---|
| `same-statement` | `theorem foo : 1 + 1 = 2 := rfl` | `theorem foo : 1 + 1 = 2 := sorry` |
| `different-statement` | `theorem foo : 1 + 1 = 2 := rfl` | `theorem foo : 2 + 2 = 4 := sorry` |
| `different-def` | `def foo : Nat := 1` | `def foo : Nat := 2` |
| `both-proved` | `theorem foo : 1 + 1 = 2 := rfl` | `theorem foo : 1 + 1 = 2 := by decide` |
| `theorem-vs-axiom` | `theorem foo : 1 + 1 = 2 := rfl` | `axiom foo : 1 + 1 = 2` |
| `two-axioms` | `axiom foo : 1 + 1 = 2` | `axiom foo : 1 + 1 = 2` |
| `theorem-vs-different-axiom` | `theorem foo : 1 + 1 = 2 := rfl` | `axiom foo : (1 + 1 = 2) ∧ False` |
| `same-def` | `def foo : Nat := 1` | `def foo : Nat := 1` |
| `theorem-vs-def` | `theorem foo : 1 + 1 = 2 := rfl` | `def foo : 1 + 1 = 2 := rfl` |

The test files run `#print foo`, which shows the copy that Lean keeps, and `#print axioms foo`. In `same-statement`, they also prove `theorem bar : 1 + 1 = 2 := foo` and run `#print axioms bar`.

## Run

`run.sh` uses the toolchains in `~/.elan/toolchains`. It writes the `.olean` files to `out/` and prints the exit code of each Lean call. If a toolchain is missing or a module that a test imports fails to compile, it exits with status 1.

```bash
./run.sh                                    # 4.28.0-rc1, 4.31.0 and 4.35.0
./run.sh leanprover--lean4---v4.33.1        # other toolchains
```

## Results (2026-10-13)

`run.sh` also ran on 4.29.0-rc4, 4.33.1, 4.34.1, `nightly-2026-10-13` (4.36.0) and the CI toolchain of PR #15556. 4.29.0-rc4 and #15556 give the same results as 4.28.0-rc1. The other three give the same results as 4.35.0. The tables below show the default toolchains.

The `same-statement` case gives no error. The table shows the body that `#print foo` shows, then the axioms that `#print axioms` reports for `foo` and `bar`:

| Lean | `GoodFirst` (`import Good`, then `import Bad`) | `BadFirst` (`import Bad`, then `import Good`) |
|---|---|---|
| 4.28.0-rc1 | `sorry`, `[sorryAx]` | `rfl`, none |
| 4.31.0 | `sorry`, none | `rfl`, `[sorryAx]` |
| 4.35.0 | `sorry`, none | `rfl`, `[sorryAx]` |

On all three versions, Lean keeps the copy from the later module in the import order. On 4.28.0-rc1, `#print axioms` agrees with that copy. On 4.31.0 and 4.35.0, `#print axioms` reports the axioms of the copy from the module that Lean imports first.

The other accepted cases give these results:

| Case | Lean | `GoodFirst` | `BadFirst` |
|---|---|---|---|
| `both-proved` | all three | `by decide`, none | `rfl`, none |
| `theorem-vs-axiom` | 4.28.0-rc1 | theorem `rfl`, none | theorem `rfl`, none |
| `theorem-vs-axiom` | 4.31.0, 4.35.0 | theorem `rfl`, none | theorem `rfl`, `[foo]` |
| `two-axioms` | all three | axiom, `[foo]` | axiom, `[foo]` |

In `theorem-vs-axiom`, Lean keeps the theorem in both orders. On 4.31.0 and 4.35.0, `#print axioms` lists `foo` as an axiom in `BadFirst`, but the kept `foo` is the theorem.

These cases fail on all three versions, in both orders: `different-statement`, `different-def`, `same-def`, `theorem-vs-def` and `theorem-vs-different-axiom`. The error is:

```
import Bad failed, environment already contains 'foo' from Good
```

So Lean accepts a duplicate in one situation only: both copies are theorems or axioms with the same statement. It rejects two identical `def`s.

## Transitive imports

The `transitive/` directory shows the same effect through an import that never mentions `foo`.

| File | Content |
|---|---|
| `Clean.lean` | `theorem foo : 1 + 1 = 2 := rfl` |
| `Shortcut.lean` | `theorem foo : 1 + 1 = 2 := by sorry` |
| `Lib.lean` | `import Clean`, `theorem bar : 1 + 1 = 2 := foo` |
| `Helpers.lean` | `import Shortcut`, `def helper : Nat := 0` |
| `OnlyLib.lean` | `import Lib`, `#print axioms bar` |
| `LibFirst.lean` | `import Lib`, `import Helpers`, then the checks below |
| `HelpersFirst.lean` | `import Helpers`, `import Lib`, then the checks below |

The checks are `#print foo`, `#print axioms foo`, `#print axioms bar`, then `theorem baz : 1 + 1 = 2 := foo` and `#print axioms baz`. `HelpersFirst` is the alphabetical order, which an import sorter produces.

`OnlyLib` reports no axioms for `bar` on all three versions. The other files report:

| Lean | File | kept `foo` | `foo` | `bar` (imported) | `baz` (new) |
|---|---|---|---|---|---|
| 4.28.0-rc1 | `LibFirst` | `sorry` | `[sorryAx]` | `[sorryAx]` | `[sorryAx]` |
| 4.28.0-rc1 | `HelpersFirst` | `rfl` | none | none | none |
| 4.31.0, 4.35.0 | `LibFirst` | `sorry` | none | none | none |
| 4.31.0, 4.35.0 | `HelpersFirst` | `rfl` | `[sorryAx]` | none | `[sorryAx]` |

On 4.28.0-rc1, all results agree with the kept `foo`. But the import order decides whether `bar` reports `sorryAx`, although `Lib` compiled `bar` against the clean `foo`.

On 4.31.0 and 4.35.0, `foo` and the new `baz` report the axioms of the `foo` from the first import. The imported `bar` keeps the result from the compilation of `Lib`. Thus `bar` and `baz` have the same proof, `:= foo`, but different results in one file. In `LibFirst`, all three report no axioms, but the kept `foo` contains `sorry`.

`run.sh` runs this test after the cases.

## Warnings

Lean gives no warning about a duplicate in any case. Each duplicate is either an import error or silently accepted. Lean reports `sorry` only in the declaration that contains it. Thus `bar` gets no warning for its use of the `sorry` copy of `foo`.

The only warnings in the run come from compiling `Bad.lean` or `Shortcut.lean` alone. The `sorry` cases give `declaration uses 'sorry'`. On 4.35.0, `theorem-vs-def` gives a `linter.defProp` warning to use `theorem` instead of `def`.

## Cause

We read the source but did not debug it. The paths are relative to `src/lean/Lean/` in the toolchain.

`finalizeImport` in `Environment.lean` merges the constants of all imported modules into one map. If a name is already in the map, Lean calls `subsumesInfo`. For two theorems, the check compares the name, the type, the universe parameters and the `all` list. It does not compare the proofs.

A theorem also passes against an axiom with the same name and type. For two axioms, the type must also be a proposition. If the check passes, Lean gives no error. If the new copy subsumes the earlier copy, Lean replaces the earlier copy in the map. Two copies with the same statement subsume each other, so the last module wins. A theorem subsumes an axiom, but an axiom does not subsume a theorem, so the theorem wins in both orders.

The same loop fills `const2ModIdx` with `insertIfNew`, so this map keeps the first module that declares a name.

4.28.0-rc1 collects axioms by walking the proofs, so its results agree with the kept copy. [leanprover/lean4#13117](https://github.com/leanprover/lean4/pull/13117), merged on 2026-03-27 and first released in v4.30.0-rc1, added stored axiom data. We did not run the tests on 4.30.0. Lean computes this data at the time that it writes the `.olean` file of a module. `#print axioms` reads it for imported constants. `ExportedAxiomsState.find?` in `Util/CollectAxioms.lean` finds the module through `getModuleIdxFor?`, which uses `const2ModIdx`. Thus it reads the data of the first module, while the environment holds the copy of the last module. The 4.31.0 source also has this code, and the 4.29.0-rc4 source does not.

The open [leanprover/lean4#15556](https://github.com/leanprover/lean4/pull/15556) removes the stored axiom data. With it, non-module files walk the proofs of imported theorems again. We ran `run.sh` with its CI toolchain, `leanprover/lean4-pr-releases:pr-release-15556` (2026-10-08). All results agree with the kept copy, in both import orders, including the imported `bar` in the transitive test. We did not test files that use the module system.

## Documentation

The Lean manuals do not describe this behavior. The [Source Files and Modules](https://lean-lang.org/doc/reference/latest/Source-Files-and-Modules/) chapter of the reference manual does not mention duplicate declarations. The [Lean.Environment API page](https://leanprover-community.github.io/mathlib4_docs/Lean/Environment.html) lists `finalizeImport` and `throwAlreadyImported` without the rule.

The only statement of the rule is the docstring of the private function `subsumesInfo` in the 4.35.0 source:

```
Returns `true` if `cinfo₁` and `cinfo₂` represent the same theorem/axiom, with `cinfo₁` potentially
being a richer representation; under the module system, a theorem may be weakened to an axiom when
exported. We allow different modules to prove the same theorem.

Motivation: We want to generate equational theorems on demand and potentially
in different files, and we want them to have non-private names.
...
Remark: we do not check whether the theorem `value` field match. This feature is useful and
ensures the proofs for equational theorems do not need to be identical. This decision
relies on the fact that theorem types are propositions, we have proof irrelevance,
and theorems are (mostly) opaque in Lean. For `Acc.rec`, we may unfold theorems
during type-checking, but we are assuming this is not an issue in practice,
and we are planning to address this issue in the future.
```

The rule is intentional. Lean designed it for generated equation lemmas such as `foo.eq_1`, which two modules can generate independently. The code does not limit the rule to generated lemmas, so it also applies to hand-written theorems. The docstring does not mention `sorry` or `#print axioms`, and it does not say which copy Lean keeps.

Related links:

- [rbeauchamp/regula#128](https://github.com/rbeauchamp/regula/issues/128): a replay checker rejects an equation lemma that Lean accepts from two modules.
- [leanprover/lean4#15559](https://github.com/leanprover/lean4/pull/15559): importing modules regenerate such lemmas more often.

A search of the lean4 GitHub issues and PRs (2026-10-13) found no report of this behavior. The search terms were `duplicate theorem import`, `subsumesInfo`, `"already contains" import theorem axioms`, `collectAxioms`, `print axioms duplicate` and `exportedAxiomsExt OR const2ModIdx axioms`. The relevant results are [leanprover/lean4#3668](https://github.com/leanprover/lean4/pull/3668), "feat: allow duplicate theorems to be imported", which has no description, and the two PRs in the section above. This search is not complete, and we did not search Zulip.

[rocq-isabelle-comparison.md](rocq-isabelle-comparison.md) explains why Lean merges duplicates in diamond imports, and how Rocq and Isabelle avoid the merge. The `diamond/` directory holds the Lean test for that case. The `rocq/` and `isabelle/` directories hold the tests for the other two provers.

## Consequence for verification tools

A project can import the `sorry` copy of a theorem while the proved copy is also on the import path. On the tested versions from 4.31.0 to `nightly-2026-10-13`, `#print axioms` can then miss the `sorry` in the copy that Lean keeps. It can also report a `sorry` that the kept copy does not use. In the same way, it can report an axiom for a theorem that Lean keeps as a theorem. Lean gives no warning in any of these cases. These tests do not show a kernel soundness bug, because `1 + 1 = 2` also has an axiom-free proof in the same environment. We did not examine other cases. The problem is that `#print axioms` does not describe the proofs in the environment.
