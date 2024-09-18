resource "google_storage_bucket" "input" {
	project		= local.project
	name		= "${local.project}-input"
	location	= local.region
	storage_class	= "STANDARD"
	uniform_bucket_level_access = true
	force_destroy	= true
}

resource "google_storage_bucket" "output" {
	project		= local.project
	name		= "${local.project}-output"
	location	= local.region
	storage_class	= "STANDARD"
	uniform_bucket_level_access = true
	force_destroy	= true
}

resource "google_storage_bucket_iam_binding" "binding" {
	bucket = google_storage_bucket.output.name
	role = "roles/storage.objectViewer"
	members	= [
		"allUsers"
	]
}

data "google_storage_project_service_account" "gcs_account" {
	project = local.project
}

resource "google_pubsub_topic_iam_binding" "binding" {
	topic   = google_pubsub_topic.ipxe.id
	role    = "roles/pubsub.publisher"
	members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "notification" {
	bucket         = google_storage_bucket.input.name
	payload_format = "JSON_API_V1"
	topic          = google_pubsub_topic.ipxe.id
	event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
	depends_on = [
		google_pubsub_topic_iam_binding.binding
	]
}

output "input" {
	value = google_storage_bucket.input.name
}
output "output" {
	value = google_storage_bucket.output.name
}
