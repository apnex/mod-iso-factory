locals {
	project	= var.gcp_project_id
	region	= var.gcp_region
	zone	= var.gcp_zone
}

resource "google_pubsub_topic" "ipxe" {
	project	= local.project
	name	= "ipxe"
}

resource "google_service_account" "cloudbuild_sa" {
	project = local.project
        account_id = "cloud-sa"
}

resource "google_project_iam_member" "act_as" {
	project = local.project
	role    = "roles/iam.serviceAccountUser"
	member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "logs_writer" {
	project = local.project
	role    = "roles/logging.logWriter"
	member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "object_user" {
	project = local.project
	role    = "roles/storage.objectUser"
	member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_cloudbuild_trigger" "ipxe-trigger" {
	project		= local.project
	name		= "ipxe-trigger"
	description	= "pipeline to compile ipxe iso images"
        service_account = google_service_account.cloudbuild_sa.id
	pubsub_config {
		topic = google_pubsub_topic.ipxe.id
	}
	substitutions = {
		_EVENT_TYPE	= "$(body.message.attributes.eventType)"
		_BUCKET_ID	= "$(body.message.attributes.bucketId)"
		_OBJECT_ID	= "$(body.message.attributes.objectId)"
	}
	filter	= "_EVENT_TYPE.matches('OBJECT_FINALIZE') && _OBJECT_ID.endsWith('ipxe')"

	build {
		step {
			name		= "gcr.io/cloud-builders/gsutil"
			args		= [
				"cp",
				"gs://$PROJECT_ID-input/$_OBJECT_ID",
				"/workspace/$_OBJECT_ID"
			]
		}
		step {
			name		= "australia-southeast1-docker.pkg.dev/labops/apnex/ipxe-builder"
			entrypoint	= "bash"
			args		= [
				"-c",
				"/usr/bin/make -C /usr/src/ipxe/src bin/ipxe.iso EMBED=/workspace/$_OBJECT_ID && cp /usr/src/ipxe/src/bin/ipxe.iso /workspace/$_OBJECT_ID.iso && ls -la /workspace"
			]
			allow_failure = true
		}
		step {
			name		= "gcr.io/cloud-builders/gsutil"
			args		= [
				"cp",
				"/workspace/$_OBJECT_ID.iso",
				"gs://$PROJECT_ID-output/"
			]
		}
		options {
			logging	= "CLOUD_LOGGING_ONLY"
		}
	}
        depends_on = [
                google_project_iam_member.act_as,
                google_project_iam_member.logs_writer,
                google_project_iam_member.object_user
        ]
}
