Require Import A.
Lemma foo : 1 + 1 = 2. Proof. Admitted.
Lemma c (x y : t) (H : x = y) (P : forall z, z = y -> Prop) (p : P y eq_refl) : P x H.
Proof. rewrite H. exact p. Qed.
