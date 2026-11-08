#!/usr/bin/env bash
# CUPS backend: hands the job's PDF to the submitting user's session, which
# converts it to SVG (see convert.sh). Runs as cups:lp.
#
# Usage (from CUPS): print2svg job user title copies options [file]

PATH=@path@

# Without arguments, CUPS is asking which devices this backend provides.
if [ $# -eq 0 ]; then
  echo 'direct print2svg "Unknown" "Print to SVG"'
  exit 0
fi

job=$1 user=$2 title=$3

case $user in
  "" | */* | .*) echo "ERROR: invalid user '$user'" >&2; exit 5 ;;
esac

dir=/var/spool/print2svg/$user
if [ ! -d "$dir" ] || [ ! -w "$dir" ]; then
  echo "ERROR: $user is not set up for printing to SVG" >&2
  exit 5 # CUPS_BACKEND_CANCEL: drop the job but keep the queue running
fi

# cupsd runs backends with umask 077, which would leave the files unreadable
# by the user. The spool dir itself is private, so this exposes nothing.
umask 022

# PDFs reach us unfiltered (see print2svg.ppd) so pages keep their own size
# and orientation. That means applying any page range here. Print dialogs
# apply ranges themselves, so this is for e.g. `lp -P 2-3`.
ranges=
set -f
for opt in $5; do
  case $opt in page-ranges=*) ranges=${opt#page-ranges=} ;; esac
done
set +f

select_pages() { # in out
  local npages lo hi r pages=()
  npages=$(qpdf --show-npages "$1") || return
  local IFS=,
  for r in $ranges; do
    lo=${r%-*} hi=${r#*-}
    [ -n "$lo" ] || lo=1
    # Open-ended ranges ("5-") may arrive as "5-" or "5-2147483647".
    { [ -n "$hi" ] && [ "$hi" -le "$npages" ]; } || hi=$npages
    pages+=("$lo-$hi")
  done
  qpdf "$1" --pages . "${pages[*]}" -- "$2"
}

# Write under a temporary name so the watcher only sees complete files.
printf '%s\n' "$title" > "$dir/$job.title" &&
  cat "${6:--}" > "$dir/$job.in.tmp" &&
  if [ -n "$ranges" ]; then
    select_pages "$dir/$job.in.tmp" "$dir/$job.pdf.tmp"
  else
    mv "$dir/$job.in.tmp" "$dir/$job.pdf.tmp"
  fi &&
  mv "$dir/$job.pdf.tmp" "$dir/$job.pdf"
status=$?

rm -f "$dir/$job.in.tmp" "$dir/$job.pdf.tmp"
if [ $status -ne 0 ]; then
  rm -f "$dir/$job.title"
  exit 1
fi
