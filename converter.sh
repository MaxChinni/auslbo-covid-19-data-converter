#!/bin/bash

TMP_TXT=
TMP=

cleanup()
{
    local ret=$?
    [[ -r $TMP_TXT ]] && rm "$TMP_TXT"
    [[ -r $TMP ]] && rm "$TMP"
    exit $ret
}

extractDateFromFilename()
{
    local extrDate
    extrDate="$(basename "$1" | sed -r 's/^.*\s([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4}).*$/\3-\2-\1/')"
    date +'%Y-%m-%d' -d "$extrDate"
}

convertPDFtoTXT()
{
    pdftotext -layout "$1" "$TMP_TXT"
}

normalizeFile()
{
    # Add a useful new line
    sed -i -r 's// /g' "$TMP_TXT"
    sed -i -r 's/^( *Distribuzione per Comune delle persone positive a SARS-CoV-2)$/\n\1/' "$TMP_TXT"

    # Remove second column for "Numero di persone guarite"
    awk '
    {
        if ($0 == "" && cut) {
            cut = 0
            for (c in leftHalf) {
                print leftHalf[c]
            }
            print ""
            for (c in rightHalf) {
                print rightHalf[c]
            }
        } else if ( (pos = match($0, "Numero di persone guarite$")) != 0 ) {
            cut = pos
        } else if (! cut) {
            print
        }

        if (cut) {
            c++
            leftHalf[c] = substr($0, 1, cut - 1)
            rightHalf[c] = substr($0, cut)
        }
    }' "$TMP_TXT" > "$TMP"
    mv "$TMP" "$TMP_TXT"
}

parseFile()
{
    convertPDFtoTXT "$1"
    normalizeFile

    awk -v theDate="$theDate" '
        function printData()
        {
            for (il = 1; il < l; il++) {
                printf "%s,%s,", theDate, section
                for (ic = 1; ic < maxc; ic++) {
                    printf "%s,", tline[il"@"ic]
                }
                printf "\n"
            }
        }

        function trim(s) {
            sub(/ *$/, "", s);
            sub(/^ */, "", s);
            return s;
        }

        function normalizeLine(line, result)
        {
            # Init result as array
            split("", result)

            # Add a double space between numbers
            line = gensub(/^(.*[0-9]+) ([\+\-][0-9]+.*)$/, "\\1  \\2", "g", line)

            # split line in words (two spaces needed)
            split(line, word, "  ")

            i = 1
            for (x in word) {
                word[x] = trim(word[x])
                if (word[x] != "") {
                    result[i] = word[x]
                    i++
                }
            }
        }
        BEGIN {
            # Config
            knownHeaders["Numero di persone positive a SARS-CoV-2"] = "^Numero di persone positive a SARS-CoV-2$"
            knownHeaders["Numero di persone in isolamento fiduciario in sorveglianza"] = "^Numero di persone in isolamento fiduciario in sorveglianza$"
            knownHeaders["Numero di persone decedute"] = "^Numero di persone decedute$"
            knownHeaders["Distribuzione per Comune delle persone positive a SARS-CoV-2"] = "^Distribuzione per Comune delle persone positive a SARS-CoV-2$"
            knownHeaders["Distribuzione per Comune delle persone in isolamento fiduciario in sorveglianza"] = "^Distribuzione per Comune delle persone in isolamento fiduciario in sorveglianza$"
            knownHeaders["Numero di persone guarite clinicamente"] = "^Numero di persone guarite clinicamente$"
            knownHeaders["Numero di persone guarite"] = "^Numero di persone guarite$"
            knownHeaders["Numero di persone decedute per Comune di residenza"] = "^Numero di persone decedute per Comune di residenza$"
            knownHeaders["Casi positivi per Distretto per 10.000 abitanti"] = "^Casi positivi per Distretto per 10.000 abitanti.*$"

            # Init
            l = 1 # table line
            maxc = 0 # max number of columns
            section = ""
        }
        {
            line = trim($0)

            if (line == "" && ! section) {
                next
            } else if (line ~ /Totale |Alcune caratteristiche dei casi positivi/) {
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
                    regex = knownHeaders[k]
                    if (match(line, regex)) {
                        section = k
                        break
                    }
                }

                if (section == "") {
                    # unk line
                    #print "DEBUG", "SECTION", section, "LINE:", line, "LENGTH", length(line)
                }
            }

            prevLine = line
        }' "$TMP_TXT"
}

trap 'cleanup' EXIT INT TERM
TMP_TXT=$(mktemp)
TMP=$(mktemp)

for f in "$@"; do
    theDate=$(extractDateFromFilename "$f")
    [[ -z $theDate ]] && { echo "$(basename "$0"): cannot get date for $f" >&2; exit 2; }
    parseFile "$f"
done
