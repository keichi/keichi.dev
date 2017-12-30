#!/bin/bash

hugo
aws s3 sync public/ s3://keichi.net --delete --exclude ".DS_Store"
