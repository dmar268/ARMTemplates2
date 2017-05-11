# Project XYZ (PaaS)

This template allows you to deploy a Web App linked to a Git Repository. 

A new Service Plan, a new Web App, and Web App files from your Git Repository will be automatically deployed.

## Usage

Click on the **Deploy to Azure** button below. This will open the Azure Portal (login if necessary) and start a Custom Deployment. The following Parameters will be shown and must be updated / selected accordingly. 

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmrptsai%2FExternal-Cloud%2Fmaster%2Ftest-webapp%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

## Parameters

- baseUrl
  - Select the appropriate Repository Base URL containing Pattern Templates and Resource Templates
  - Default is 'https://raw.githubusercontent.com/mrptsai/External-Cloud/'.

- baseBranch
  - Select the appropriate Repository branch
  - Default is 'master'.
  
- webAppName
  - Enter a unique Name for the Web App.

- webAppHostName
  - Enter a unique Name for the Web App hostname.

- servicePlanName
  - Enter a unique Name for the Service Plan.
  
- servicePlanSize
  - Specify the existing Service Plan Size.
  - Default is 'F1' unless overridden.
  - Allowed Values are:
  ```
       1 - F1
       2 - D1
       3 - B1
       4 - B2
       5 - B3
       6 - S1
       7 - S2
       8 - S3
       9 - P1
       10 - P2
       11 - P3
       12 - P4
  ```
- servicePlanWorkerSize
  - Enter the instance size of the Service Plan (small, medium, or large).
  - Default is '0 (small)' unless overridden.
  - Allowed Values are:
  ```
       0 - small
       1 - medium
       2 - large
  ```
  
- repoURL
  - The URL for the GitHub repository that contains the project to deploy.
  
- branch
  - The branch of the GitHub repository to use.
  
## Prerequisites

- Access to Azure

## Versioning

We use [Github](http://github.com/) for version control.

## Authors

* **Paul Towler** - *Initial work* - [External-Cloud](https://github.com/mrptsai/External-Cloud)

See also the list of [contributors](https://github.com/mrptsai/External-Cloud/graphs/contributors) who participated in this project.
