#!/bin/bash

# Start AWS X-Ray in background
/usr/bin/xray --bind=0.0.0.0:2000 --bind-tcp=0.0.0.0:2000 &

# Start app
dotnet dotnet-xray-example.dll
