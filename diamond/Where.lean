import Lean
import B
import C
-- Lists every imported module that declares `f.eq_1`.
open Lean in
#eval show CoreM Unit from do
  let env ← getEnv
  for h : i in [0:env.header.moduleNames.size] do
    if env.header.moduleData[i]!.constNames.contains `f.eq_1 then
      IO.println s!"f.eq_1 is declared in {env.header.moduleNames[i]}"
