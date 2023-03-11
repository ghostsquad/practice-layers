// Constants-ish
// see https://jsonnet.org/ref/stdlib.html std.type(x)
local ARRAY_TYPE = "array";
local OBJECT_TYPE = "object";

// TODO contribute this back to lonely-mountain
local ArrayOrWrap(input) = if std.type(input) == ARRAY_TYPE then input else [input];

{
  version: "3",
  tasks+: {
    // TODO add a header comment to the yaml file that it's a generated file
    // with instructions on how to regenerate it, e.g. task taskfile:gen
    "taskfile:gen": $.Task("taskfile:gen")
      .WithCmds(
        // TODO these tools need an automated hook for installation
        "jsonnet {{.JSONNET_INPUT_FILE}} | dasel -f - -r json -w yaml --pretty > '{{.OUTPUT_FILE}}'"
      )
      .WithVars({
        JSONNET_INPUT_FILE: "taskfile.jsonnet",
        OUTPUT_FILE: "Taskfile.yml",
      })
    ,
  },

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
