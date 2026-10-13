Require Import B C.
Locate foo.
Lemma bar : 1 + 1 = 2. Proof. exact foo. Qed.
Lemma bar2 : 1 + 1 = 2. Proof. exact B.foo. Qed.
Print bar.
Print bar2.
Print Assumptions bar.
Print Assumptions bar2.
Locate internal_eq_rew_r_dep.
Print B.b.
