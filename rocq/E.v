Require Import A.
(* The same dependent rewrite as in B.v, but the proof ends with Defined. *)
Lemma e (x y : t) (H : x = y) (P : forall z, z = y -> Prop) (p : P y eq_refl) : P x H.
Proof. rewrite H. exact p. Defined.
Locate internal_eq_rew_r_dep.
