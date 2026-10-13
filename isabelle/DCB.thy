theory DCB imports C B begin
(* Shows which fact the short name foo selects, then the oracles that bar uses. *)
ML \<open>writeln (@{make_string} (Global_Theory.check_fact @{theory} ("foo", Position.none)))\<close>
lemma bar: "PROP Q ==> PROP Q" by (rule foo)
ML \<open>writeln (@{make_string} (Thm_Deps.all_oracles [@{thm bar}]))\<close>
end
