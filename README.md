# Personal AI on IBM Cloud Code Engine (Ollama + Open WebUI)

This repo deploys:
- Ollama (backend model server)
- Open WebUI (frontend)
- Cloud Object Storage (S3-compatible persistence for Open WebUI)

## Why you still see Container Registry (even with "Option C")

Code Engine runs container images. If you do not build/push locally, you can ask Code Engine to build images for you, but the resulting image still needs to live in a registry so Code Engine can run it.

Code Engine also supports building container images. 

## Prerequisites

- IBM Cloud CLI + Code Engine plugin
- Terraform >= 1.5
- An IBM Cloud API key

IBM Code Engine build/run docs:
- Running a build configuration (buildrun submit) 
- Code Engine apps default port and how to change it 

Open WebUI docs:
- OLLAMA_BASE_URL 
- S3 storage variables (STORAGE_PROVIDER=S3, S3_ENDPOINT_URL, etc.) 

## Repo structure

- ollama/Dockerfile
- webui/Dockerfile
- terraform/*

## Step 1: Configure Terraform variables

From `terraform/`:

```bash
export TF_VAR_ibmcloud_api_key="YOUR_IBM_CLOUD_API_KEY"
export TF_VAR_region="eu-es"              # example
export TF_VAR_prefix="ai"                # example
export TF_VAR_resource_group="code"      # example
export TF_VAR_cr_namespace="private-ai-ns"