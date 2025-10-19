#!/bin/bash

hugo
rsync -vrP public/ root@rohitsan.xyz:/var/www/home/public
