variable project { }

provider "google" {
  project = "${var.project}"
}

provider "helm" {
    kubernetes {
    }
}