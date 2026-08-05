#!/bin/bash

# Description: Copy the dotfiles in the repo to your (Linux) machine
# Run from within the repo project

# Generate dotfiles that exist in user's home

home_dotfiles=(
  .bunfig.toml
  .npmrc
  .tmux.conf
  .vimrc
)

for file in "${home_dotfiles[@]}"; do
  [[ -f "$file" ]] || continue
  ln -sf "${PWD}/${file}" "${HOME}/${file}"
  echo "${file} linked."
done

# Generate dotfiles requiring location in .config/

mkdir -p ~/.config
config_dir="${HOME}/.config"

ln -sf "${PWD}/uv.toml" "${config_dir}/uv/uv.toml"
echo "uv.toml linked."

echo "All dotfiles linked!"
