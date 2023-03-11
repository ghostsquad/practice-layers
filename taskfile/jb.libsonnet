local lm = import "github.com/cakehappens/lonely-mountain/main.libsonnet";
local t = import "./taskfile.libsonnet";

{
  env+: {
    local env = self,
    JSONNETPKG_HOME: "jsonnet-vendor",
    jsonnetPath_+:: {
      [env.JSONNETPKG_HOME]: true,
      vendor: true,
    },
    JSONNET_PATH: std.join(":", lm.obj.keysAfterPrune(self.jsonnetPath_))
  },
  tasks+: {
    "jb:install": t.Task("jb:install")
      .WithCmds("jb install --jsonnetpkg-home='jsonnet-vendor' {{.CLI_ARGS}}")
    ,
    "jb:update": t.Task("jb:install")
      .WithCmds("jb update --jsonnetpkg-home='jsonnet-vendor' {{.CLI_ARGS}}")
    ,
  }
}
