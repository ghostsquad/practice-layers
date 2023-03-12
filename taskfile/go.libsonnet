local t = import "./taskfile.libsonnet";

// Constants-ish
// see https://jsonnet.org/ref/stdlib.html std.type(x)
local STRING_TYPE = 'string';

{
//  GoRun(tool)::
//    local name = if std.type(tool) == STRING_TYPE then tool else tool.String();
//    'go run %s' % [name],

  config_+:: {
    project+: {
      name: error "project.name required",
      owner: error "project.repoOwner required",
      repoShort: std.join("/", [self.owner, self.name]),
      repoLong: std.join("/", ["github.com", self.repoShort]),
    },
    tools+: {
      local tools = self,

      gotestsum+: {
        src: 'gotest.tools/gotestsum',
        ref: 'latest',
      },
    },
  },

  env+: {
    GO111MODULE: 'auto',
    GOPRIVATE: std.join("/", ["github.com", $.config_.project.owner]),
    GOPROXY: 'https://proxy.golang.org,direct',
  },

  # TODO Var order matters, but since this file is dynamically generated from jsonnet, we lose ordering
  # Regenerating this file will result in problems. Don't forget to fix the ordering in the interm
  # https://github.com/go-task/task/issues/1051
  vars+: {
    APP_IMAGE: 'docker.io/%s:{{.GIT_COMMIT}}' % [$.config_.project.repoShort],
    CURRENT_GO_VERSION: {
      sh: "asdf current golang | awk '{ print $2 }'",
    },
    DEBIAN_IMAGE: 'debian:{{.DEBIAN_VERSION}}-slim',
    DEBIAN_VERSION: 11.5,
    DEBIAN_VERSION_CODENAME: 'bullseye',
    EXPECTED_GO_VERSION: '1.19.2',
    EXPECTED_GO_VERSION_SHORT: |||
      {{slice (.EXPECTED_GO_VERSION | splitList ".") 0 2 | join "."}}
    |||,
    GIT_BRANCH: {
      sh: |||
        if [ "${CI:-}" == "true" ]; then
          echo "${GITHUB_REF_NAME}";
        else
          git branch --show-current; fi
      |||,
    },
    GIT_COMMIT: {
      sh: 'git rev-parse HEAD',
    },
    GIT_COMMIT_SHORT: {
      sh: 'git rev-parse --short=8 HEAD',
    },
    GOLANG_BUILDER_IMAGE: 'golang:{{.CURRENT_GO_VERSION}}-{{.DEBIAN_VERSION_CODENAME}}',
  },
  tasks+: {
    // TODO figure out how to dedup the key and parameter in an idiomatic way
    build: t.Task('build')
      .WithCmds(
        |||
          docker buildx build \
            --tag {{.APP_IMAGE}} \
            --build-arg GOLANG_BUILDER_IMAGE={{.GOLANG_BUILDER_IMAGE}} \
            --build-arg DEBIAN_IMAGE={{.DEBIAN_IMAGE}} \
            {{.BUILD_ARGS}} \
            .
        |||,
      )
      .WithLabel('build with {{.BUILD_ARGS}}')
      .WithVars({
        BUILD_ARGS: '{{.BUILD_ARGS}}',
      })
    ,
    download: t.Task('download')
      .WithCmds('go mod download')
    ,
    "git:status:dirty": t.Task('git:status:dirty')
      .WithCmds('[ -z "$(git status --porcelain=v1 2>/dev/null)" ]')
    ,
    "go:version:get": t.Task('go:version:get')
      .WithCmds('echo {{.CURRENT_GO_VERSION}}')
    ,
    "go:version:set": t.Task('go:version:set')
      .WithCmds([
          'go mod edit --go={{.GO_VERSION_SHORT}}',
          'asdf install golang {{.GO_VERSION}}',
          'asdf local golang {{.GO_VERSION}}',
          'go mod tidy',
      ])
      .WithVars({
        GO_VERSION: '{{.CLI_ARGS | default .EXPECTED_GO_VERSION}}',
        GO_VERSION_SHORT: |||
          {{slice (.GO_VERSION | splitList ".") 0 2 | join "."}}
        |||,
      })
    ,
    "go:version:update": t.Task('go:version:update')
      .WithCmds(
        // This seems weird, since we already have the name
        // however, if this task were to disappear, we'd get a error during rendering
        // If we just relied on the string, we'd only see an error at runtime
        t.CmdTask($.tasks['go:version:set'].name_)
          .WithVars({
              GO_VERSION: {
              sh: 'asdf latest golang',
            },
          })
      )
    ,
    "go:version:verify": t.Task('go:version:verify')
      .WithCmds([
        t.CmdTask($.tasks['go:version:set'].name_),
        t.CmdTask($.tasks['git:status:dirty'].name_),
      ])
    ,
    "http:metrics": t.Task('http:metrics')
      .WithCmds('http localhost:8080/metrics')
    ,
    "install-tools": t.Task('install-tools')
      .WithCmds([
        {
          cmd: 'echo Installing tools from tools.go',
          silent: true,
        },
        'asdf install',
        |||
          cat hack/tools.go | grep _ | awk -F'"' '{print $2}' | xargs -tI % go install %
        |||,
      ])
      .WithDeps($.tasks.download.name_)
    ,
    publish: t.Task('publish')
      .WithCmds(
      t.CmdTask($.tasks.build.name_)
        .WithVars({
          BUILD_ARGS: |||
            --platform linux/amd64
            --push
          |||,
        })
      )
    ,
    run: t.Task('run')
      .WithCmds('go run ./...')
    ,
    'test:integration': t.Task('test:integration')
      .WithCmds(
        |||
          APP_IMAGE='{{.APP_IMAGE}}' \
          docker-compose \
            --file docker-compose.tests.integration.yml \
              up \
              --exit-code-from test \
              --abort-on-container-exit \
            ;
        |||
      )
      .WithDeps([
        t.CmdTask($.tasks.build.name_)
          .WithVars({
            BUILD_ARGS: '--output=type=docker',
          })
        ,
      ])
    ,

    local testTypes = ['unit', 'race', 'bench'],

    "test:all": t.Task('test:all')
      .WithCmds([
        t.CmdTask($.tasks['test:' + testType].name_),
        for testType in testTypes
      ])
    ,
    "test:all:ci": t.Task('test:all:ci')
      .WithCmds([
        t.CmdTask($.tasks['test:%s:ci' % [testType]].name_),
        for testType in testTypes
      ])
    ,
    "test:bench": t.Task('test:bench')
      // TODO DRY this up as compared to the other test tasks
      .WithCmds('gotestsum --format short-verbose -- -count=1 -bench=. -run=^$$')
      .WithDeps($.tasks['install-tools'].name_)
    ,
    "test:race": t.Task("test:race")
      .WithCmds('gotestsum --format short-verbose -- -count=1 -race')
      .WithDeps($.tasks['install-tools'].name_)
    ,
    "test:unit": t.Task("test:unit")
      .WithCmds('gotestsum --format short-verbose -- -count=1')
      .WithDeps($.tasks['install-tools'].name_)
    ,
    "test:race:ci": t.Task("test:race:ci")
      .WithCmds('gotestsum --junitfile reports/race-tests.xml -- -count=1 -race')
      .WithDeps($.tasks['install-tools'].name_)
    ,
    "test:bench:ci": t.Task("test:bench:ci")
      .WithCmds('gotestsum --junitfile reports/bench-tests.xml -- -count=1 -bench=. -run=^$$')
      .WithDeps($.tasks['install-tools'].name_)
    ,
    "test:unit:ci": t.Task("test:unit:ci")
      .WithCmds('gotestsum --junitfile reports/unit-tests.xml -- -count=1')
      .WithDeps($.tasks['install-tools'].name_)
  },
}
