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
        tr -d '' | \
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
            knownHeaders[4] = "Distribuzione per Comune delle persone positive a SARS-CoV-2"
            knownHeaders[5] = "Distribuzione per Comune delle persone in isolamento fiduciario in sorveglianza"
            knownHeaders[6] = "Numero di persone guarite clinicamente"
            knownHeaders[7] = "Numero di persone guarite"

            # Init
            tableTitle = ""
            l = 1 # table line
            maxc = 0
            section = ""
        }
        {
            line = trim($0)
            if (cut > 1) {
                line = trim(substr(line, 1, cut - 1))
            }
            print "DEBUG", cut, "SECTION", section, "LINE:", line, "LENGTH", length(line)

            if (line == "") {
                next
            } else if (line ~ /Totale /) {
                # End section
                printData()
                section = ""
                maxc = 0
                l = 0
                cut = 1
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
                        cut = 1
                        section = h
                        break
                    }
                    if (h == "Numero di persone guarite") {
                        if ( (cut = match(line, " "h"$")) > 1 ) {
                            section = h
                            break
                        }
                    }
                }

                if (section == "") {
                    # unk line
                    print "DEBUG", "SECTION", section, "LINE:", line, "LENGTH", length(line)
                }
            }

            prevLine = line
        }'
}

for f in "$@"; do
    theDate=$(extractDateFromFilename "$f")
    parseFile "$f"
done
