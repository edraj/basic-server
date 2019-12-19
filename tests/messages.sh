#!/bin/bash -x
curl --silent -H @tests/headers -X POST -d @tests/create-message.json http://localhost:3000/api/ | jq
curl --silent -H @tests/headers -d @tests/query-request.json http://localhost:3000/api/ | jq
