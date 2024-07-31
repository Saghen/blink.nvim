# Written by echasnovski in mini.nvim
# https://github.com/echasnovski/mini.nvim/blob/82584a42c636efd11781211da1396f4c1f5e7877/scripts/dual_sync.sh

# Perform local sync of standalone repositories
repos_dir=dual/repos
patches_dir=dual/patches

mkdir -p $repos_dir
mkdir -p $patches_dir

sync_module () {
  # First argument is a string with module name. Others - extra paths to track
  # for module.
  module=$1
  shift

  repo="$( realpath $repos_dir/blink.$module )"
  patch="$( realpath $patches_dir/blink.$module.patch )"

  printf "\n\033[1mblink.$module\033[0m\n"

  # Possibly pull repository
  if [[ ! -d $repo ]]
  then
    printf "Pulling\n"
    github_repo="blink.$module"
    git clone --filter=blob:none https://github.com/saghen/$github_repo.git $repo
  else
    printf "No pulling (already present)\n"
  fi

  # Make patch with commits from 'sync' branch to current HEAD which affect
  # files related to the module
  printf "Making patch\n"
  git format-patch sync..HEAD --output $patch -- \
    lua/blink/$module \
    readmes/$module \
    .gitignore \
    .stylua.toml \
    LICENSE \
    "$@"

  # Do nothing if patch is empty
  if [[ ! -s $patch ]]
  then
    rm $patch
    printf "Patch is empty\n"
    return
  fi

  # Tweak patch:
  # - Move 'readmes/xxx/*' to the top level. This should modify only patch
  #   metadata, and not text (assuming it uses 'readmes/mini-xxx.md' on
  #   purpose; as in "use [this link](https://.../readmes/mini-xxx.md)").
  # TODO: handle relative links
  sed -i 's|readmes/[^/]*/\(.*\)|\1|g' $patch

  # Apply patch
  printf "Applying patch\n"
  cd $repo
  git am $patch
  cd - > /dev/null
}

sync_module "chartoggle"
sync_module "clue"
sync_module "cmp" Cargo.toml Cargo.lock flake.nix flake.lock build.rs build-ffi-bindings.sh
sync_module "indent"
sync_module "select"
sync_module "tree"
