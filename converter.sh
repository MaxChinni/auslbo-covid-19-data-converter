#!/bin/bash

extractDateFromFilename()
{
    local extrDate

    extrDate="$(basename "$1" | sed -r 's/^.*([0-9]{2})\.([0-9]{2})\.([0-9]{4}).*$/\3-\2-\1/')"
    date +'%Y-%m-%d' -d "$extrDate"
}

extractDateFromFilename "$1"

pdftotext "$1" - | \
    tr -d '' | \
    awk '
    function printData()
    {
        if (length(labels) == 0) {
            return
        }
        printf "\n# %s\n\n", title
        printf "| %-30s | %3s |\n", labelName, " n "
        printf "+--------------------------------+-----+\n", labelName, ""
        for (h in labels) {
            printf "| %-30s | %3d |\n", labels[h], values[h]
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
        } else if ($0 == "Distretto") {
            if (prevLine != "") {
                title = prevLine
            }
            section = $0
            labelName = $0
            c = 0
        } else if ($0 == "Comune") {
            title = prevLine
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
