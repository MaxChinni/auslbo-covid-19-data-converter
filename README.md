# Data extractor for AUSL Bologna Covid-19

Data from https://www.ausl.bologna.it/per-i-cittadini/coronavirus/report-casi-positivi-e-in-sorveglianza.

## Usage examples

### Basic extraction

### Fuzzy finder

    sudo apt install fzf
    ./converter.sh data/Report*.pdf | fzf

### Graph

    sudo apt install gnuplot python-q-text-as-data
    ./converter.sh data/Report*.pdf | \
        q -d, -H 'SELECT date, n FROM - WHERE label LIKE "%positive%" AND place = "Vergato" ORDER BY 1' | \
        tr -d '-' | \
        gnuplot -p -e 'set terminal png; plot "/dev/stdin"' > /tmp/graph.png && \
        xdg-open /tmp/graph.png
