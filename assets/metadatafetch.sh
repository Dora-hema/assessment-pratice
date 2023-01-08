#!bin/bash

echo "Enter type of metadata"
read my_var
curl curl "http://metadata.google.internal/computeMetadata/v1/instance/${my_var}/?recursive=true" -H "Metadata-Flavor: Google" > metadata.json
