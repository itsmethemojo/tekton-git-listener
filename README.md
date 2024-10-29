# tekton-git-listener

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

generic git repository listener to run tekton pipelines on new commits and/or tags

# Installation with helm

see [chart on artifact hub](https://artifacthub.io/packages/helm/itsmethemojo/tekton-git-listener)

# Local execution

For local usage you need at least `yq` ([see](https://github.com/mikefarah/yq)) and `git` installed. You can then test the functionality of the `examples/without_authentification` config
```
KUBECTL_BINARY=./mocks/kubectl ./run.sh
```

If you have kubectl access to your kubernetes cluster with tekton setup you can also test the pipeline creation locally by not using the mock command
```
./run.sh
```

**NOTE** that the script will create local state data in the tmp folder holding information about already fetched commits/tags.
If you want to start from scratch you have to clean up this by.

```
rm -rf tmp/
```

generic git repository listener to run tekton pipelines on new commits and/or tags

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| app.command[0] | string | `"bash"` |  |
| app.command[1] | string | `"/scripts/run.sh"` |  |
| app.env.CONFIG_DIR | string | `"/config"` | Directory to find the `listeners.yaml` and `repositories.yaml` in |
| app.env.CREATE_INITIAL_PIPELINES | string | `"false"` | If set to true on the first run pipelines for all matched branch/tags that already exists will be created. If set to false only new commits/tags added after starting this script will be considered. |
| app.env.DAEMON_MODE | string | `"true"` | If set to true this script will periodically run every `$PULL_INTERVALL` seconds |
| app.env.DATA_DIR | string | `"/tmp/data"` | Directory where current branch/tag ref data is stored to be compared. TODO this should be a PVC |
| app.env.GIT_CLONE_DIR | string | `"/tmp/clone"` | Directory where git repositories will be cloned for watching |
| app.env.KUBECTL_DOWNLOAD_URI | string | `"https://dl.k8s.io/release/v1.31.2/bin/linux/amd64/kubectl"` | To be able to use generic containers, this defines a download URI for the kubectl binary. if left empty the script will use the kubectl binary found in PATH |
| app.env.PULL_INTERVALL | string | `"300"` | Intervall in seconds where all defined repositories will be watched for new commit/tag refs. |
| app.env.YQ_DOWNLOAD_URI | string | `"https://github.com/mikefarah/yq/releases/download/v4.27.5/yq_linux_amd64"` | To be able to use generic containers, this defines a download URI for the yq binary. if left empty the script will use the yqa binary found in PATH |
| app.env.tmp_dir | string | `"/tmp/definitions"` | Directory to store temporary created tekton pipeline run definitions |
| app.extraVolumeMounts[0].mountPath | string | `"/scripts"` |  |
| app.extraVolumeMounts[0].name | string | `"scripts"` |  |
| app.extraVolumeMounts[1].mountPath | string | `"/config"` |  |
| app.extraVolumeMounts[1].name | string | `"config"` |  |
| app.extraVolumes[0].configMap.name | string | `"tekton-git-listener-scripts"` |  |
| app.extraVolumes[0].name | string | `"scripts"` |  |
| app.extraVolumes[1].name | string | `"config"` |  |
| app.extraVolumes[1].secret.secretName | string | `"tekton-git-listener-config"` |  |
| app.fullnameOverride | string | `"tekton-git-listener"` |  |
| app.image.repository | string | `"buildpack-deps"` | This image will miss the yq and kubectl binary. You might choose an image with both available and disbale `$KUBECTL_DOWNLOAD_URI` and `$YQ_DOWNLOAD_URI` |
| app.image.tag | string | `"scm"` |  |
| app.livenessProbe | string | `""` |  |
| app.readinessProbe | string | `""` |  |
| app.serviceAccount.create | bool | `false` |  |
| app.serviceAccount.name | string | `"tekton-git-listener"` | make sure this name aligns with `base.fullnameOverride` |
| app.startupProbe | string | `""` |  |
| config.listeners | list | `[{"pipeline_name":"your-pipeline-run-name","pipeline_run_template":"apiVersion: tekton.dev/v1beta1\nkind: PipelineRun\nmetadata:\n  name: __NAME__\nspec:\n  pipelineRef:\n    name: your-awesome-tekton-pipeline-template\n  params:\n  - name: repo-url\n    value: __URL__\n  - name: git-revision\n    value: __REVISION__\n  - name: branch\n    value: __BRANCH__\n","ref_filter":"refs/heads/main","url":"https://github.com/itsmethemojo/tekton-git-listener.git"}]` | List of watch definitions |
| config.listeners[0].pipeline_name | string | `"your-pipeline-run-name"` | Name prefix of the tekton pipeline run that will be created |
| config.listeners[0].pipeline_run_template | string | `"apiVersion: tekton.dev/v1beta1\nkind: PipelineRun\nmetadata:\n  name: __NAME__\nspec:\n  pipelineRef:\n    name: your-awesome-tekton-pipeline-template\n  params:\n  - name: repo-url\n    value: __URL__\n  - name: git-revision\n    value: __REVISION__\n  - name: branch\n    value: __BRANCH__\n"` | The yaml definition template for the tekton pipeline run that will be created. Make sure you use the `__NAME__` placeholder to get a generic name for this pipeline run. Also make use of the `__URL__`, `__REVISION__`, `__SHORT_REVISION__` and `__BRANCH__` placeholders to get run specific inputs. |
| config.listeners[0].ref_filter | string | `"refs/heads/main"` | This filters the refs as displayed in git ls-remote. choose "refs/heads/" to watch only branches, or "refs/tags/" to watch only tags. You can also leave it out completely to watch everything of both. |
| config.listeners[0].url | string | `"https://github.com/itsmethemojo/tekton-git-listener.git"` | Url has to match the url in the `repositories` list |
| config.repositories | list | `[{"url":"https://github.com/itsmethemojo/tekton-git-listener.git"}]` | List of repositories to be watched for new commits/tags. for each you can add the `token` attribute to use access tokens. TODO the listener pod does not automatically reload on config file changes yet |
| config.repositories[0].url | string | `"https://github.com/itsmethemojo/tekton-git-listener.git"` | HTTPS clone url of the git repository |

## Source Code

* <https://github.com/itsmethemojo/tekton-git-listener>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://itsmethemojo.github.io/helm-charts/ | app(basic-web-app) | 1.2.1 |

## Update docs

```
docker run --rm -v $(pwd):/app -w/app jnorwood/helm-docs -t helm-docs-template.gotmpl
```