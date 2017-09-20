#!/bin/bash

hugo
aws s3 sync public/ s3://blog.keichi.net --delete --exclude ".DS_Store"
