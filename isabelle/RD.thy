theory RD imports RB RC begin
(* Both RB and RC declare the fact foo with the full name foo. *)
ML \<open>writeln (@{make_string} (Global_Theory.check_fact @{theory} ("foo", Position.none)))\<close>
end
