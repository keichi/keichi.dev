#!/bin/bash

hugo
cd public
msg="Update on `date '+%Y/%m/%d %H:%M:%S'`"
if [ $# -eq 1 ]
    then msg="$1"
fi
git add -A
git commit -m "$msg"
git push origin master

