#!/bin/sh
# Used by git filter-branch to clean historical commit messages.
sed -E \
  -e '/^[Cc]o-[Aa]uthored-[Bb]y:/d' \
  -e '/Generated with.*[Cc]laude/d' \
  -e '/^🤖 Generated/d' \
  -e '/^🚀 Generated/d' \
  -e '/^🎯 Generated/d'
