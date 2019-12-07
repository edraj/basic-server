#!/bin/bash
curl -H @tests/headers -d @tests/query-request.json http://localhost:3000/api/ | jq
