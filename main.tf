locals {
  rg_name       = "${var.prefix}-${var.resource_group}"
  project_name  = "${var.prefix}-project"
  cos_name      = "${var.prefix}-cos"
  hmac_key_name = "${var.prefix}-cos-hmac-creds"

  # If bucket name not provided, generate one deterministically.
  bucket_name = var.cos_bucket_name != "" ? var.cos_bucket_name : "${var.prefix}-chat-history-data"

  # IBM Container Registry regional endpoint typically uses: <region>.icr.io
  # (Example: us-south.icr.io)
  icr_server = "${var.icr_region}.icr.io"

  ollama_image = "${local.icr_server}/${var.cr_namespace}/ollama-deepseek:${var.ollama_image_tag}"
  webui_image  = "${local.icr_server}/${var.cr_namespace}/open-webui:${var.webui_image_tag}"

  # Open WebUI S3 settings per upstream docs:
  # STORAGE_PROVIDER=S3 and S3_* variables.  [oai_citation:0‡Open WebUI](https://docs.openwebui.com/tutorials/maintenance/s3-storage/?utm_source=chatgpt.com)
  s3_endpoint_url = "https://s3.${var.region}.cloud-object-storage.appdomain.cloud"
}

# --- 1. RESOURCE GROUP ---
resource "ibm_resource_group" "ai_rg" {
  name = local.rg_name
}

# --- 2. CONTAINER REGISTRY NAMESPACE ---
resource "ibm_cr_namespace" "ai_namespace" {
  name              =  var.cr_namespace
  resource_group_id = ibm_resource_group.ai_rg.id
}

# --- 3. OBJECT STORAGE & HMAC ---
resource "ibm_resource_instance" "cos_instance" {
  name              = local.cos_name
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = ibm_resource_group.ai_rg.id
}

resource "ibm_resource_key" "cos_hmac_key" {
  name                 = local.hmac_key_name
  resource_instance_id = ibm_resource_instance.cos_instance.id
  role                 = "Writer"
  parameters           = { HMAC = true }
}

resource "ibm_cos_bucket" "chat_storage" {
  bucket_name          = local.bucket_name
  resource_instance_id = ibm_resource_instance.cos_instance.id

  # Region-scoped bucket. Must match where you want the bucket to live.
  region_location = var.region

  storage_class = "standard"
}

# --- 4. CODE ENGINE PROJECT ---
resource "ibm_code_engine_project" "ai_project" {
  name              = local.project_name
  resource_group_id = ibm_resource_group.ai_rg.id
}

# --- 5. CODE ENGINE APPS ---
#
# Note on ports:
# Code Engine defaults to port 8080. If your app listens on a different port,
# you must set the correct port.  [oai_citation:1‡cloud.ibm.com](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads&utm_source=chatgpt.com)
#
# The code-engine module app submodule exposes input "image_port".  [oai_citation:2‡Terraform Registry](https://registry.terraform.io/modules/terraform-ibm-modules/code-engine/ibm/3.2.1/submodules/app?utm_source=chatgpt.com)

resource "null_resource" "push_images" {
  triggers = {
    ollama_tag = local.ollama_image
    webui_tag  = local.webui_image
    # opcional: fuerza rebuild si cambian Dockerfiles
    ollama_dockerfile = filesha256("${path.module}/ollama/Dockerfile")
    webui_dockerfile  = filesha256("${path.module}/webui/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOT
set -e

ibmcloud cr region-set ${var.region}
ibmcloud cr login

docker build -f ${path.module}/ollama/Dockerfile -t ${local.ollama_image} ${path.module}
docker push ${local.ollama_image}

docker build -f ${path.module}/webui/Dockerfile -t ${local.webui_image} ${path.module}
docker push ${local.webui_image}
EOT
  }

  depends_on = [ibm_cr_namespace.ai_namespace]
}

module "ollama_app" {

  depends_on = [null_resource.push_images]

  source  = "terraform-ibm-modules/code-engine/ibm//modules/app"
  version = "3.2.1"

  project_id      = ibm_code_engine_project.ai_project.id
  name            = "ollama-engine"
  image_reference = local.ollama_image
  image_port      = 11434

  # IMPORTANT: no public route
  managed_domain_mappings = "local"

  run_env_variables = [
    {
      type  = "literal"
      name  = "OLLAMA_HOST"
      value = "0.0.0.0:11434"
    }
  ]
}

module "webui_app" {
  source  = "terraform-ibm-modules/code-engine/ibm//modules/app"
  version = "3.2.1"

  project_id      = ibm_code_engine_project.ai_project.id
  name            = "open-webui"
  image_reference = local.webui_image
  image_port      = 8080

  managed_domain_mappings = "local_public"

  run_env_variables = [
    # Open WebUI: point to Ollama.
    # If you later make Ollama endpoint "private/project-only", you will want to switch
    # this to the project internal URL form: http://<app>.<subdomain>.svc.cluster.local
    # IBM shows project-only URLs in that format.  [oai_citation:3‡cloud.ibm.com](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app&utm_source=chatgpt.com)
    {
      type  = "literal"
      name  = "OLLAMA_BASE_URL"
      value = module.ollama_app.endpoint_internal
    },

    # Authentication defaults to enabled. This keeps it explicit.  [oai_citation:4‡Open WebUI](https://docs.openwebui.com/getting-started/quick-start/?utm_source=chatgpt.com)
    {
      type  = "literal"
      name  = "WEBUI_AUTH"
      value = "true"
    },

    # S3 persistence for Open WebUI per upstream docs.  [oai_citation:5‡Open WebUI](https://docs.openwebui.com/tutorials/maintenance/s3-storage/?utm_source=chatgpt.com)
    {
      type  = "literal"
      name  = "STORAGE_PROVIDER"
      value = "S3"
    },
    {
      type  = "literal"
      name  = "S3_ENDPOINT_URL"
      value = local.s3_endpoint_url
    },
    {
      type  = "literal"
      name  = "S3_REGION_NAME"
      value = var.region
    },
    {
      type  = "literal"
      name  = "S3_BUCKET_NAME"
      value = ibm_cos_bucket.chat_storage.bucket_name
    },

    # HMAC credentials for COS.
    # Important: this will store secrets in Terraform state. Prefer Code Engine secrets for production.
    {
      type  = "literal"
      name  = "S3_ACCESS_KEY_ID"
      value = ibm_resource_key.cos_hmac_key.credentials["cos_hmac_keys.access_key_id"]
    },
    {
      type  = "literal"
      name  = "S3_SECRET_ACCESS_KEY"
      value = ibm_resource_key.cos_hmac_key.credentials["cos_hmac_keys.secret_access_key"]
    }
  ]
}