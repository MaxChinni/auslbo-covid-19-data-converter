#!/bin/bash

pdftotext "$1" - | \
    tr -d '' | \
    awk '
    function printData()
    {
        if (length(labels) == 0) {
            return
        }
        print "#", title
        for (h in labels) {
            printf "%30s | %d\n", labels[h], values[h]
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
            c = 0
        } else if ($0 == "Comune") {
            title = prevLine
            section = $0
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
