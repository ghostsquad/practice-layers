// Constants-ish
// see https://jsonnet.org/ref/stdlib.html std.type(x)
local ARRAY_TYPE = "array";
local OBJECT_TYPE = "object";

// TODO contribute this back to lonely-mountain
local ArrayOrWrap(input) = if std.type(input) == ARRAY_TYPE then input else [input];

{
  Task(name):: {
    name_:: name,
    run: 'once',
    WithLabel(label):: self + {
      label: label,
    },
    WithCmds(cmds):: self + {
      cmds+: ArrayOrWrap(cmds),
    },
    WithVars(vars):: self + {
      assert std.type(vars) == OBJECT_TYPE,
      vars+: vars,
    },
    WithDeps(deps):: self + {
      deps+: ArrayOrWrap(deps),
    },
  },

  CmdTask(name):: {
    task: name,
    WithVars(vars):: self + {
      assert std.type(vars) == OBJECT_TYPE,
      vars+: vars,
    }
  }
}
