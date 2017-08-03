#!/bin/bash

for psfile in $(ls *.ps); do
    echo "$psfile"
    pdffile="${psfile%%.ps}.pdf"
    ps2pdf "$psfile" && pdfcrop --margins '0 0 0 0' "$pdffile" "$pdffile"
done

exit 0
