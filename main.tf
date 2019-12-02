/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  prefix       = var.prefix == "" ? "" : join("-", list(var.prefix, lower(var.location), ""))
  names_set    = toset(var.names)
  buckets_list = [for name in var.names: google_storage_bucket.buckets[name]]
  first_bucket = local.buckets_list[0]
}

resource "google_storage_bucket" "buckets" {
  for_each      = local.names_set

  name          = "${local.prefix}${lower(each.value)}"
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  labels        = merge(var.labels, { name = "${local.prefix}${lower(each.value)}" })
  force_destroy = lookup(
    var.force_destroy,
    lower(each.value),
    false,
  )
  bucket_policy_only = lookup(
    var.bucket_policy_only,
    lower(each.value),
    true,
  )
  versioning {
    enabled = lookup(
      var.versioning,
      lower(each.value),
      false,
    )
  }
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                   = lookup(lifecycle_rule.value.condition, "age", null)
        created_before        = lookup(lifecycle_rule.value.condition, "created_before", null)
        with_state            = lookup(lifecycle_rule.value.condition, "with_state", null)
        is_live               = lookup(lifecycle_rule.value.condition, "is_live", null)
        matches_storage_class = contains(keys(lifecycle_rule.value.condition), "matches_storage_class") ? split(",", lifecycle_rule.value.condition["matches_storage_class"]) : null
        num_newer_versions    = lookup(lifecycle_rule.value.condition, "num_newer_versions", null)
      }
    }
  }

}

resource "google_storage_bucket_iam_binding" "admins" {
  for_each = var.set_admin_roles ? local.names_set : []
  bucket   = google_storage_bucket.buckets[each.value].name
  role     = "roles/storage.objectAdmin"
  members  = compact(
    concat(
      var.admins,
      split(
        ",",
        lookup(var.bucket_admins, each.value, ""),
      ),
    ),
  )
}

resource "google_storage_bucket_iam_binding" "creators" {
  for_each = var.set_creator_roles ? local.names_set : []
  bucket   = google_storage_bucket.buckets[each.value].name
  role     = "roles/storage.objectCreator"
  members  = compact(
    concat(
      var.creators,
      split(
        ",",
        lookup(var.bucket_creators, each.value, ""),
      ),
    ),
  )
}

resource "google_storage_bucket_iam_binding" "viewers" {
  for_each = var.set_viewer_roles ? local.names_set : []
  bucket   = google_storage_bucket.buckets[each.value].name
  role     = "roles/storage.objectViewer"
  members  = compact(
    concat(
      var.viewers,
      split(
        ",",
        lookup(var.bucket_viewers, each.value, ""),
      ),
    ),
  )
}
