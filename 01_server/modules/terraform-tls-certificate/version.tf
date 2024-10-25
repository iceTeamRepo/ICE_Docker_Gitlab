terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }    
  }
  required_version = ">= 0.15"
}
