local lm = import "github.com/cakehappens/lonely-mountain/main.libsonnet";
local t = import "./taskfile.libsonnet";

{
  config_+: {
    jsonnetBundler: {
      pkgHome: "vendor",
    },
  },
  env+: {
    local env = self,
    jsonnetPath_+:: {
      vendor: true,
    },
    JSONNET_PATH: std.join(":", lm.obj.keysAfterPrune(self.jsonnetPath_))
  },
  tasks+: {
    // TODO DRY these commands up
    "jb:install": t.Task("jb:install")
      .WithCmds("jb install --jsonnetpkg-home='%s' {{.CLI_ARGS}}" % [$.config_.jsonnetBundler.pkgHome])
    ,
    "jb:update": t.Task("jb:install")
      .WithCmds("jb update --jsonnetpkg-home='%s' {{.CLI_ARGS}}" % [$.config_.jsonnetBundler.pkgHome])
    ,
  }
}
