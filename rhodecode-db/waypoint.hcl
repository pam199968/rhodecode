project = "forge/rhodecode/rhodecode-db"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/eriegel/rhodecode.git"
        ref  = "main"
		path = "/rhodecode-db"
		ignore_changes_outside_path = true
    }
}

app "rhodecode-db" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
	        disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/rhodecode-database.nomad.tpl", {
            image   = var.image
            tag     = var.tag
            datacenter = var.datacenter
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "henix_docker_platform_integ"
}

variable "image" {
    type    = string
    default = "prosanteconnect/rhodecode-database"
}

variable "tag" {
    type    = string
    default = "13.5"
}
