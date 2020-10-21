# dotnet-xray-example

Example of an .NET Core Web Application using the AWS X-Ray.

This repo have the code already done, but the instructions below will guide you throw all the steps required to set up a .NET application and instruments it to send the APM data to the AWS X-Ray.

**ATTENTION**: It'll not work if you are running locally! You must be inside a EC2 instance or Fargate. Check the official documentation if you want to run locally: https://docs.aws.amazon.com/xray/latest/devguide/xray-daemon-local.html

## Requirements

Before we start, you'll need the following packages:
- .NET Core: https://docs.microsoft.com/en-us/dotnet/core/install/linux-centos
- Docker: `sudo amazon-linux-extras install docker`

I'm using `Amazon Linux 2` to run this test.

## Preparing the environment

### IAM permissions

Your application will need custom permissions to send data to the X-Ray service.

- For ECS: add the policy below to the `Task Execution Role`.
- For EC2: add the policy below to the `Instance Role`.

AWS has a policy already created called `AWSXRayDaemonWriteAccess`. You can just attach it. Or you can create a new one using the JSON below:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords",
                "xray:GetSamplingRules",
                "xray:GetSamplingTargets",
                "xray:GetSamplingStatisticSummaries"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

## Application

### Creating a sample application

Create a new web application using the `dotnet` CLI:

```bash
# Go to the new project dir
# (must be an empty dir)
mkdir -p ~/projects/dotnet-xray-example
cd ~/projects/dotnet-xray-example

# Create the project from scaffold
dotnet new webapp
```

### Instrumenting the application

Install the libraries:

https://www.nuget.org/packages/AWSXRayRecorder.Handlers.AspNetCore/

```bash
dotnet add package AWSXRayRecorder.Handlers.AspNetCore --version 2.7.1
```

Add the X-Ray to the startup application. Pay attention to the three parts:
- Libraries at the beggining of the file
- Configuration reader at `public Startup(IConfiguration configuration)`
- The middleware responsible to send the data to the X-Ray Daemon at `public void Configure(IApplicationBuilder app, IWebHostEnvironment env)`

**File**: [./Startup.cs](./Startup.cs)
```cs

[...]

using Amazon.XRay.Recorder.Core;
using Amazon.XRay.Recorder.Handlers.AspNetCore;
namespace dotnet_xray_example
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;

            // AWS X-Ray
            // pass IConfiguration object that reads appsettings.json file
            AWSXRayRecorder.InitializeInstance(configuration);
        }


        [...]

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        { 
            
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
                
                // AWS X-Ray (production mode only)
                // Application name
                app.UseXRay("dotnet-test");
            }
            
        [...]
```

### Setting up the X-Ray daemon

Does exist two parts to setup the daemon:

1. First, install the daemon. I'll consider that you'll use Linux container to run the application:

**File**: [./Dockerfile](./Dockerfile)
```dockerfile
[...]
COPY ./entrypoint.sh ./out/
[...]
RUN set -x \
    # Install AWS X-Ray Daemon
    && apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https curl ca-certificates wget \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q https://s3.us-east-2.amazonaws.com/aws-xray-assets.us-east-2/xray-daemon/aws-xray-daemon-3.x.deb \
    && dpkg -i aws-xray-daemon-3.x.deb \
    # Set permission
    && chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
```

2. Second, create the `entrypoint.sh` script to start the X-Ray Daemon, then start the application:

**File**: [./entrypoint.sh](./entrypoint.sh)
```bash
#!/bin/bash

# Start AWS X-Ray in background
/usr/bin/xray --bind=0.0.0.0:2000 --bind-tcp=0.0.0.0:2000 &

# Start app
dotnet dotnet-xray-example.dll
```

# Test

```bash
make build
make run

# Server will start at http://localhost:5000
```
