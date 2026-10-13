theory RB imports Pure begin
setup \<open>Sign.root_path\<close>
lemma foo: "PROP P ==> PROP P" by assumption
end
