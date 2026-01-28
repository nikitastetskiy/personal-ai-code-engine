output "resource_group_name" {
  value = ibm_resource_group.ai_rg.name
}

output "code_engine_project_name" {
  value = ibm_code_engine_project.ai_project.name
}

# output "open_webui_endpoint" {
#   value = module.webui_app.endpoint
# }

output "cos_bucket_name" {
  value = ibm_cos_bucket.chat_storage.bucket_name
}