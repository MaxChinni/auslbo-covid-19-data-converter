#!/bin/bash

extractDateFromFilename()
{
    local extrDate

    extrDate="$(basename "$1" | sed -r 's/^.*([0-9]{2})\.([0-9]{2})\.([0-9]{4}).*$/\3-\2-\1/')"
    date +'%Y-%m-%d' -d "$extrDate"
}

parseFile()
{
    pdftotext -layout "$1" - | \
        awk -v theDate="$theDate" '
        function printData()
        {
            print "#", section
            for (il = 1; il < l; il++) {
                for (ic = 1; ic < maxc; ic++) {
                    printf "%30s | ", tline[il"@"ic]
                }
                printf "\n"
            }
        }
        function trim(s) {
            sub(/ *$/, "", s);
            sub(/^ */, "", s);
            return s;
        }
        function normalizeLine(line, tok)
        {
            split("", tok, "  ")
            split(line, tok2, "  ")
            i = 1
            for (x in tok2) {
                tok2[x] = trim(tok2[x])
                if (tok2[x] != "") {
                    tok[i] = tok2[x]
                    i++
                }
            }
        }
        BEGIN {
            # Config
            knownHeaders[1] = "Numero di persone positive a SARS-CoV-2"
            knownHeaders[2] = "Numero di persone in isolamento fiduciario in sorveglianza"
            knownHeaders[3] = "Numero di persone decedute"

            # Init
            tableTitle = ""
            l = 1 # table line
            maxc = 0
            section = ""
        }
        {
            line = trim($0)
            print "DEBUG", "SECTION", section, "LINE:", line, "LENGTH", length(line)

            if (line ~ /Totale /) {
                # End section
                printData()
                section = ""
                maxc = 0
                l = 0
                delete tline
            } else if (section != "") {
                # Working on a section
                if (trim(line) != "") {
                    normalizeLine(line, tok)
                    c = 1
                    for (x in tok) {
                        tline[l"@"c] = tok[x]
                        c++
                    }
                    maxc = c > maxc ? c : maxc
                    l++
                }
            } else {
                for (k in knownHeaders) {
                    h = knownHeaders[k]
                    if (line == h) {
                        print "++++",h
                        section = h
                        tableTitle = h
                        break
                    }
                }
            }

#              if ($0 ~ /^[[:space:]]*$/) {
#                  # empty line
#                  if (section == "values" && c > 0) {
#                      printData()
#                      split("", labels, ":")
#                  }
#              } else if ($0 ~ /^Numero /) {
#                  title = $0
#                  gsub("/^ *(.*) *$/", "xx \1", title)
#              } else if ($0 == "Distretto") {
#                  if (prevLine != "") {
#                      title = prevLine
#                      gsub("/^ *(.*) *$/", "xx \1", title)
#                  }
#                  section = $0
#                  labelName = $0
#                  c = 0
#              } else if ($0 == "Comune") {
#                  title = prevLine
#                  gsub("/^ *(.*) *$/", "xx \1", title)
#                  section = $0
#                  labelName = $0
#                  c = 0
#              } else if ($0 == "Totale") {
#                  section = $0
#              } else if ($0 == "∆" || $0 == "n") {
#                  # end section "Distretto"
#                  section = "values"
#                  split("", values, ":")
#                  c = 0
#              } else if (section == "Distretto" || section == "Comune") {
#                  labels[++c] = $0
#              } else if (section == "values" && $0 !~ /^\+/) {
#                  values[++c] = $0
#              }

            prevLine = line
        }'
}

for f in "$@"; do
    theDate=$(extractDateFromFilename "$f")
    parseFile "$f"
done
