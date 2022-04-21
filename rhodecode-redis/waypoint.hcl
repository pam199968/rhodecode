project = "forge/rhodecode/rhodecode-redis"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/erickriegel/rhodecode.git"
        ref  = "main"
		path = "rhodecode-redis/"
		ignore_changes_outside_path = true
    }
}

app "rhodecode-redis" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
	        disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/rhodecode-redis.nomad.tpl", {
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
    default = "ans/rhodecode-redis"
}

variable "tag" {
    type    = string
    default = "6.2.6"
}
