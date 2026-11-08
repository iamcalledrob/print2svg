# Runs in the user's session whenever print jobs land in their spool dir.
# Asks where to save each one, then converts it to SVG.

spool=/var/spool/print2svg/$USER

for pdf in "$spool"/*.pdf; do
  [ -e "$pdf" ] || continue
  job=${pdf%.pdf}

  # Suggest a name based on the job title, e.g. "Report.pdf" -> "Report".
  name=$(tr -d '[:cntrl:]' < "$job.title" 2>/dev/null | tr '/' '-' || true)
  name=${name%.[pP][dD][fF]}
  name=${name:0:200}
  [ -n "$name" ] || name=Untitled

  if dest=$(zenity --file-selection --save --title="Save as SVG" \
      --filename="$HOME/Documents/$name.svg"); then
    dest=${dest%.[sS][vV][gG]}
    {
      pages=$(pdfinfo "$pdf" | awk '/^Pages:/ { print $2 }')
      if [ "$pages" = 1 ]; then
        pdf2svg "$pdf" "$dest.svg"
      else
        # pdf2svg formats the name with printf, so escape any literal %.
        pdf2svg "$pdf" "${dest//%/%%} (page %d).svg" all
      fi
    } || zenity --error --text="Couldn't convert \"$name\" to SVG." || true
  fi

  # Always remove the job, even on failure, so it isn't retried forever.
  rm -f "$pdf" "$job.title"
done
