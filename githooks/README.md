# Git Hooks

Git hooks are scripts that are automatically run at various points in the Git cycle. You can do things
such as automatically format code, send notifications etc.

We use one, a `pre-commit` which does what it sounds like.

## Overview

### Pre-Commit

This script automatically runs the ruby linter `rubocop` against all changed files and won't let you
proceed if it can't automatically fix them

## Setup

### Set up the Git hook
1. Run bundler to make sure all of our prerequisites are installed `bundle install`
1. After cloning this repository copy all the files, except this README over to the `./.git/hooks` folder
1. Set them all to executable `sudo chmod 777 ./.git/hooks/*`

That's it! From now on everything should be running fine.
