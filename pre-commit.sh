#!/usr/bin/env bash
# Increamet dns serial after config change
# place in .git/hooks/pre-commit
set -e

if [ -z "$GIT_DIR" ]; then
  echo "Don't run this script from the command line." >&2
  exit 1
fi

if git rev-parse --is-inside-work-tree && [ "$(git symbolic-ref HEAD | sed 's!refs\/heads\/!!')" == "master" ]; then
  DATE=$(date '+%Y%m%d')
  TMP=$(mktemp -d)
  for f in $({ git diff --name-only ; git diff --name-only --staged ; } | sort | uniq); do
    echo "doing $f"
    # extract the date from the zone file
    OLDSERIAL=$(sed -n '/^@/,/^[^;]*)/H;${;x;s/.*@[^(]*([^0-9]*//;s/[^0-9].*//;p;}' "$f")
    echo "$OLDSERIAL"
    OLDDATE=$(echo "$OLDSERIAL" | cut -c1-8)
    OLDCOUNT=$(echo "$OLDSERIAL" | cut -c9-)
    if (( "$DATE" > "$OLDDATE" )); then
      # since it's already greater than the old serial, just append 00
      SERIAL="${DATE}00"
    elif (( "$DATE" == "$OLDDATE" )); then
      # we have some work to do. add 1 to the old bit
      COUNT=$(printf '%02d' $((OLDCOUNT + 1)))
      SERIAL="${DATE}${COUNT}"
    else
      # old serial number is bigger than the new one. don't bother
      SERIAL=$OLDSERIAL
      continue
    fi
    sed -n '/^@/,/^[^;]*)/H;${;x;s/.*@[^(]*([^0-9]*//;s/[^0-9].*/'"${SERIAL}"'/;p;}' "$f" >"$TMP/$f"
    if named-checkconf "$TMP/$f"; then
      cp "$TMP/$f" "$f"
      # were there actually changes?
      git diff --quiet "$f" && git add "$f"
    else
      echo Promblem in "$f"
    fi
  done
  rm -rf "$TMP"
  rndc reload
fi
exit 0
