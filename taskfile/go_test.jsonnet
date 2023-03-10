local go = import "./go.libsonnet";

go + {
  config_+:: {
    project+: {
      name: "practice-layers",
      owner: "ghostsquad",
    }
  }
}
