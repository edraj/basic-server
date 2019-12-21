#!/bin/bash

curl --silent -XPOST -F "file=@./tests/canvas.png" -F 'request=@./tests/create-media.json' http://localhost:3000/media
curl --silent -v --out x.png http://localhost:3000/media/maqola/cool/stuff/canvas.png

sha256sum x.png ./tests/canvas.png
