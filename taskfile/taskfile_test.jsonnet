local t = import "./taskfile.libsonnet";

t + {
  env+: {
    JSONNET_PATH: "../vendor",
  },
  tasks+: {
    "taskfile:gen"+: {
      vars+: {
        JSONNET_INPUT_FILE: "taskfile_test.jsonnet",
      },
    },
  },
}
