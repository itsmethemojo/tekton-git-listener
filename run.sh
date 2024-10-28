#!/bin/bash

# overload defaults with environment

pull_intervall="${PULL_INTERVALL:=30}"
tekton_namespace="${TEKTON_NAMESPACE:=tekton-pipelines}"
config_dir="${CONFIG_DIR:=examples/without_authentification}"
data_dir="${DATA_DIR:=tmp/data}"
tmp_dir="${TMP_DIR:=/tmp}"
git_clone_dir="${GIT_CLONE_DIR:=tmp/clone}"
git_binary="${GIT_BINARY:=git}"
kubectl_binary="${KUBECTL_BINARY:=kubectl}"
yq_binary="${YQ_BINARY:=yq}"
daemon_mode="${DAEMON_MODE:=false}"
create_initial_pipelines="${CREATE_INITIAL_PIPELINES:=true}"

current_dir=$(pwd)
if [[ "$(echo $config_dir | cut -c -1)" != "/" ]]
then
    config_dir="$current_dir/$config_dir"
fi
if [[ "$(echo $data_dir | cut -c -1)" != "/" ]]
then
    data_dir="$current_dir/$data_dir"
fi

repo_config="$config_dir/repositories.yaml"
listener_config="$config_dir/listeners.yaml"
current_data_dir="$data_dir/current_refs"
last_data_dir="$data_dir/last_refs"


mkdir -p "$current_data_dir"
mkdir -p "$git_clone_dir"
mkdir -p "$tmp_dir"

# lazymode so you can use only git capable containers
if [[ "$KUBECTL_DOWNLOAD_URI" != "" ]]
then
    curl -sL "$KUBECTL_DOWNLOAD_URI" -o "$tmp_dir/kubectl"
    chmod +x "$tmp_dir/kubectl"
    kubectl_binary="$tmp_dir/kubectl"
fi
if [[ "$YQ_DOWNLOAD_URI" != "" ]]
then
    curl -sL "$YQ_DOWNLOAD_URI" -o "$tmp_dir/yq"
    chmod +x "$tmp_dir/yq"
    yq_binary="$tmp_dir/yq"
fi

while true
do

    # fetch current repo branches and tags data

    while IFS=$'\t' read -r url token
    do
        cd "$current_dir"
        cd "$git_clone_dir"
        repo_id="$(echo "$url" | sed 's|[/.:]|_|g')"
        if [[ ! -d "$repo_id" ]]
        then
            if [[ "$repo_id" != "" ]]
            then
                url=$(echo $url | sed "s|https://|https://git:$token@|g")
            fi
            $git_binary clone $url "$repo_id" 2>/dev/null || rm -rf "$repo_id"
        fi
        if [[ ! -d "$repo_id" ]]
        then
            echo "[ERROR] git clone of $url failed"
        continue
        fi
        cd "$repo_id"
        $git_binary ls-remote --quiet --heads --tags 2>/dev/null | awk '{print $2": "$1}'> "$current_data_dir/$repo_id.yaml"
    done < <($yq_binary e '.[] | [.url, .token] | @tsv' "$repo_config")

    # create new pipeline for new branches and tags

    counter=0
    cd "$current_dir"
    mkdir -p "$last_data_dir"
    while IFS=$'\t' read -r url pipeline_name ref_filter
    do
        repo_id="$(echo "$url" | sed 's|[/.:]|_|g')"
        while IFS="" read -r line || [ -n "$line" ]
        do
            if [[ "$(echo "$line" | cut -d":" -f 1 | grep -c "$ref_filter")" == "0" ]]
            then
                continue
            fi
            listener_refs="$last_data_dir/$pipeline_name-$repo_id-$counter.yaml"
            if [[ ! -f "$listener_refs" ]]
            then
                if [[ "$create_initial_pipelines" != "true" ]]
                then
                    cp "$current_data_dir/$repo_id.yaml" "$listener_refs"
                fi
                touch "$listener_refs"
            fi
            if [[ "$(grep -c "$line" "$listener_refs")" == "0" ]]
            then
                branch="$(echo $line | cut -d ':' -f1 | xargs | sed "s|refs/tags/||g" | sed "s|refs/heads/||g")"
                revision="$(echo "$line" | cut -d":" -f 2| xargs)"
                short_revision=$(echo $revision | cut -c -8)
                echo "[INFO] creating pipeline for $url $line"
                token=$($yq_binary e ".[] | select(.url == \"$url\") | .token" "$repo_config")
                pipeline_file="$tmp_dir/$(date +%s.%N)"
                pipeline_id="$branch-$short_revision"
                $yq_binary ".[$counter].pipeline_run_template" "$listener_config" \
                    | sed "s|\__NAME__|$pipeline_name-$pipeline_id|g" \
                    | sed "s|\__URL__|$url|g" \
                    | sed "s|\__REVISION__|$revision|g" \
                    | sed "s|\__SHORT_REVISION__|$short_revision|g" \
                    | sed "s|\__BRANCH__|$branch|g" \
                    > $pipeline_file
                $kubectl_binary apply -n $tekton_namespace -f $pipeline_file
            fi
        done < "$current_data_dir/$repo_id.yaml"
        $yq_binary eval-all '. as $item ireduce ({}; . *+ $item )' "$listener_refs" "$current_data_dir/$repo_id.yaml" > "$listener_refs"
        ((counter++))
    done < <($yq_binary e '.[] | [.url, .pipeline_name, .ref_filter] | @tsv' "$listener_config")

    if [[ "$daemon_mode" == "false" ]]
    then
        exit 0
    fi
    sleep $pull_intervall
    echo "[INFO] sleep $pull_intervall"

done