# Written by echasnovski in mini.nvim
# https://github.com/echasnovski/mini.nvim/blob/82584a42c636efd11781211da1396f4c1f5e7877/scripts/dual_log.sh

# Check standalone repos result
local_repos="$( ls -d dual/repos/*/ )"

for repo in $local_repos; do
  printf "\n\033[1m$( basename $repo )\033[0m\n"
  cd $repo > /dev/null
  git log origin/main..main --abbrev-commit --format=oneline
  cd - > /dev/null
done
