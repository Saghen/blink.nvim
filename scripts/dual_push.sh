# Written by echasnovski in mini.nvim
# https://github.com/echasnovski/mini.nvim/blob/82584a42c636efd11781211da1396f4c1f5e7877/scripts/dual_push.sh

# Push standalone repos result
local_repos="$( ls -d dual/repos/*/ )"

for repo in $local_repos; do
  printf "\n\033[1mPushing $( basename $repo )\033[0m\n"
  cd $repo > /dev/null
  # Push only if there is something to push (saves time)
  if [ $( git rev-parse main ) != $( git rev-parse origin/main ) ]
  then
    git push origin main
  fi
  cd - > /dev/null
done

echo ''
