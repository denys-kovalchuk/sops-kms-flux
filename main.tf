terraform {
  backend "gcs" {
    bucket  = "8-2"
    prefix  = "tf/state"
  }
}

module "github_repository" {
  #source                   = "./modules/github_repository"
  source                   = "github.com/denys-kovalchuk/tf-github-repository"
  github_owner             = var.GITHUB_OWNER
  github_token             = var.GITHUB_TOKEN
  repository_name          = var.FLUX_GITHUB_REPO
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux-ssh-pub"
}

module "gke_cluster" {
  #source         = "./modules/gke_cluster"
  source = "github.com/denys-kovalchuk/tf-google-gke-cluster"
  GOOGLE_REGION  = var.GOOGLE_REGION
  GOOGLE_PROJECT = var.GOOGLE_PROJECT
  GKE_NUM_NODES  = 2
}

module "tls_private_key" {
  #source    = "./modules/tls_private_key"
  source  = "github.com/denys-kovalchuk/tf-hashicorp-tls-keys"
  algorithm = "RSA"
}

module "flux_bootstrap" {
  #source            = "./modules/flux_bootstrap"
  source = "github.com/denys-kovalchuk/tf-fluxcd-flux-bootstrap"
  github_repository = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  private_key       = module.tls_private_key.private_key_pem
  config_path = module.gke_cluster.kubeconfig
  #config_host       = module.gke_cluster.config_host
  #config_token      = module.gke_cluster.config_token
  #config_ca         = module.gke_cluster.config_ca
  github_token      = var.GITHUB_TOKEN
}

module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  name                = "kustomize-controller"
  namespace           = "flux-system"
  project_id          = var.GOOGLE_PROJECT
  location            = var.GOOGLE_REGION
  cluster_name        = "main"
  annotate_k8s_sa     = true  
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
}

module "kms" {
  source             = "github.com/denys-kovalchuk/terraform-google-kms"
  project_id         = var.GOOGLE_PROJECT
  keyring            = "sops-flux"
  location           = "global"
  keys               = ["sops-key-flux"]
  prevent_destroy    = false
}