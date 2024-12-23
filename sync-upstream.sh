#!/usr/bin/env bash

# 设置上游库
git remote add upstream https://github.com/d12frosted/homebrew-emacs-plus

# 禁止向上游push
git remote set-url --push upstream DISABLE

git fetch upstream
git merge upstream/master
