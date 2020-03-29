#!/bin/bash

extractDateFromFilename()
{
    local extrDate

    extrDate="$(basename "$1" | sed -r 's/^.*([0-9]{2})\.([0-9]{2})\.([0-9]{4}).*$/\3-\2-\1/')"
    date +'%Y-%m-%d' -d "$extrDate"
}

parseFile()
{
    pdftotext "$1" - | \
        tr -d '' | \
        awk -v theDate="$theDate" '
        function printData()
        {
            if (length(labels) == 0) {
                return
            }
            for (h in labels) {
                printf "| %s | %-80s | %-30s | %3d |\n", theDate, title, labels[h], values[h]
            }
        }
        {
            #print "DEBUG", "SECTION", section, "LINE:", $0, "LENGTH", length($0)
            if ($0 ~ /^[[:space:]]*$/) {
                # empty line
                if (section == "values" && c > 0) {
                    printData()
                    split("", labels, ":")
                }
            } else if ($0 ~ /^Numero /) {
                title = $0
                gsub("/^ *(.*) *$/", "xx \1", title)
            } else if ($0 == "Distretto") {
                if (prevLine != "") {
                    title = prevLine
                    gsub("/^ *(.*) *$/", "xx \1", title)
                }
                section = $0
                labelName = $0
                c = 0
            } else if ($0 == "Comune") {
                title = prevLine
                gsub("/^ *(.*) *$/", "xx \1", title)
                section = $0
                labelName = $0
                c = 0
            } else if ($0 == "Totale") {
                section = $0
            } else if ($0 == "∆" || $0 == "n") {
                # end section "Distretto"
                section = "values"
                split("", values, ":")
                c = 0
            } else if (section == "Distretto" || section == "Comune") {
                labels[++c] = $0
            } else if (section == "values" && $0 !~ /^\+/) {
                values[++c] = $0
            }

            prevLine = $0
        }'
}

for f in "$@"; do
    theDate=$(extractDateFromFilename "$f")
    parseFile "$f"
done
