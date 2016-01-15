#!/usr/bin/env bash
buildpack-install() {
  declare desc="Install buildpack from Git URL and optional committish"
  declare url="$1" commit="$2" vendor="${3:-custom}" name="$4"
  declare vendors_path="include/buildpacks"

  ensure-paths

  if [[ ! "$url" ]]; then
    echo "install buildpacks from vendors list"
    local vendors=($vendors_path/*)
    for list in "${vendors[@]}"; do
      if ! [[ -s $list ]] ; then continue; fi
      basename=${list##*/}
      vendor=${basename%.*}
      cat "$list" | while read url commit; do
        buildpack-install "$url" "$commit" "$vendor"
      done
    done
    return
  fi

  mkdir -p $buildpack_path/$vendor
  local target_path="$buildpack_path/$vendor/${name:-$(basename $url)}"
  if [[ "$commit" ]]; then
    if ! git clone --branch "$commit" --quiet --depth 1 "$url" "$target_path" &>/dev/null; then
      # if the shallow clone failed partway through, clean up and try a full clone
      rm -rf "$target_path"
      git clone "$url" "$target_path"
      cd "$target_path"
      git checkout --quiet "$commit"
      cd - > /dev/null
    else
      echo "Cloning into '$target_path'..."
    fi
  else
    git clone --depth=1 "$url" "$target_path"
  fi
  rm -rf "$target_path/.git"

}

buildpack-list() {
  declare desc="List installed buildpacks"
  ensure-paths
  ls -1 "$buildpack_path"

}

buildpack-sources() {

  local repo=($1)
  local branch=($2)

  cd $app_path
  rm -rf * .??*
  cd -

  git clone "$repo" "$app_path" > /dev/null ; cd $app_path
  if [[ -n $branch ]]; then git checkout "$branch" > /dev/null; fi
  git submodule update --init --recursive > /dev/null

}

buildpack-detect() {

  ensure-paths
  [[ "$USER" ]] || randomize-unprivileged

  local vendors=("lastbackend" "heroku" "custom")
  for vendor in "${vendors[@]}"; do
    if [[ "$selected_name" ]]; then break; fi
    local buildpacks=($buildpack_path/$vendor/*)
    for buildpack in "${buildpacks[@]}"; do
      selected_name="$(unprivileged $buildpack/bin/detect $app_path)" \
        && selected_path="$buildpack" \
        && break
    done
  done

  if [[ "$selected_path" ]] && [[ "$selected_name" ]]; then
    echo "$selected_name"
    return 0;
  fi;

  if [[ -f "$app_path/Dockerfile" ]]; then
    echo "Docker"
    return 0;
  fi

  echo "Unable to select a buildpack"
  return 1;

}

# Build app with buildpack
buildpack-build() {
  declare desc="Build an application using installed buildpacks"
  ensure-paths
  [[ "$USER" ]] || randomize-unprivileged
  buildpack-setup # > /dev/null
  buildpack-dockerize "$@" | indent
  #procfile-types    | indent

}

buildpack-setup() {

  # Buildpack expectations
  export APP_DIR="$app_path"
  export HOME="$app_path"
  export REQUEST_ID="build-$RANDOM"

  # clear build path if something exists

  if ! [[ -d "$build_path" ]]; then
    mkdir "$build_path"
  fi

  rm -rf "$build_path/app"
  rm -rf "$build_path/pack"
  rm -rf "$build_path/env"
  rm -rf "$build_path/cache"
  rm -rf "$build_path/Dockerfile"

  cp -r "$app_path/" "$build_path/app"
  mkdir "$build_path/env"
  mkdir "$build_path/cache"


  # Prepare dropped privileges
  usermod --home "$HOME" "$unprivileged_user" > /dev/null 2>&1
  chown -R "$unprivileged_user:$unprivileged_group" \
    "$app_path" \
    "$build_path" \
    "$cache_path" \
    "$buildpack_path"

  # Useful settings / features
  export CURL_CONNECT_TIMEOUT="30"

  # Buildstep backwards compatibility
  if [[ -f "$app_path/.env" ]]; then
    source "$app_path/.env"
  fi

}

buildpack-dockerize() {

  declare desc="Generate pack for dockerbuild build"
  declare build_name=${1:-}
  declare ready

  title "Dockerize application to $build_name Docker image"
  # check for buildname
  if ! [[ "$build_name" ]]; then
    echo "Error: no image name provided"
    exit 1;
  fi

  # Dockerfile detected
  if [[ -f "$app_path/Dockerfile" ]]; then
    echo "Build with app internal Dockerfile"
    cd $build_path/app
    selected_name="docker"
    selected_path="$build_path/app"
  fi

  if ! [[ $selected_name ]]; then cd $build_path; fi

  # Check if we need to use remote buildpack
  if [[ -n "$BUILDPACK_URL" ]] && ! [[ $selected_name ]]; then
    # cleanup pack
    rm -rf "$build_path/pack"
    title "Fetching custom buildpack"
    IFS='#' read url commit <<< "$BUILDPACK_URL"
    buildpack-install "$url" "$commit" custom &> /dev/null
    chown -R "$unprivileged_user:$unprivileged_group" "$build_path/pack"
    selected_name="fetched"
    selected_path="$build_path/pack"
  fi

  if [[ -n "$BUILDPACK_LOCAL" ]] && ! [[ $selected_name ]]; then
    title "Using custom buildpack from local path $BUILDPACK_LOCAL"
    cp -r $BUILDPACK_LOCAL "$build_path/pack"
    chown -R "$unprivileged_user:$unprivileged_group" "$build_path/pack"
    selected_name="local"
    selected_path="$build_path/pack"
  fi

  # Try to build with Last.Backend buildpack
  if ! [[ $selected_name ]]; then
    local vendors=("lastbackend" "heroku" "custom")
    for vendor in "${vendors[@]}"; do

      echo "try to find $vendor buildpack"
      local buildpacks=($buildpack_path/$vendor/*)
      for buildpack in "${buildpacks[@]}"; do
        if ! [[ -f $buildpack/bin/detect ]]; then continue; fi
        selected_name="$(unprivileged $buildpack/bin/detect $app_path)" \
        && selected_path="$buildpack" \
        && break
      done

      if [[ $selected_name ]] && [[ $selected_path ]]; then
        echo "Buildpack founded, copy to buildpath"
        cp -r "$selected_path" "$build_path/pack"
        break
      fi
    done
  fi

  if ! [[ $selected_path ]] || ! [[ $selected_name ]]; then
    title "Buildpack is not found to build this app"
    exit 1
  fi


  if [[ -f $build_path/pack/bin/dockerize ]]; then
    echo "Dockerizer founded"
    unprivileged $build_path/pack/bin/dockerize $build_path
  fi

  if ! [[ -f $build_path/Dockerfile ]] && [[ $selected_name != 'docker' ]]; then
    cat $dockerfile_path/cedar > $build_path/Dockerfile
  fi

  docker build --rm -t ${build_name} . | indent

}

buildpack-export() {

  local image=${1:-}
  local namespace=${2:-}

  title "Start pushing image to registry"
  echo "$image  $namespace"
  docker tag -f "$image" "$namespace"
  docker push "$namespace"
}

buildpack-cleanup() {

  local image=${1:-}
  local namespace=${2:-}

  docker rmi -f "$image"
  if [[ "$namespace" ]]; then
    docker rmi -f "$namespace"
  fi

}
