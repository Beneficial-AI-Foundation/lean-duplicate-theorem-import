Require Import A.
Lemma foo : 1 + 1 = 2. Proof. reflexivity. Qed.
(* A dependent rewrite makes Rocq generate the scheme internal_eq_rew_r_dep. *)
Lemma b (x y : t) (H : x = y) (P : forall z, z = y -> Prop) (p : P y eq_refl) : P x H.
Proof. rewrite H. exact p. Qed.
