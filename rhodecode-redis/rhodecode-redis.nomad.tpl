job "rhodecode-redis" {
        datacenters = ["${datacenter}"]
        type = "service"
        vault {
                policies = ["forge"]
                change_mode = "restart"
        }

        group "rhodecode-redis" {
                count = 1

                restart {
                  attempts = 3
                  delay = "60s"
                  interval = "1h"
                  mode = "fail"
                }

                constraint {
                  attribute = "$\u007Bnode.class\u007D"
                  value     = "data"
                }

                update {
                  max_parallel      = 1
                  min_healthy_time  = "30s"
                  progress_deadline = "5m"
                  healthy_deadline  = "2m"
                }

                network {
                  port "redis" { to = 6379 }
                }
                volume "rhodecode_data" {
                        type            = "csi"
                        source          = "rh-data"
                        read_only        = false
                        attachment_mode = "file-system"
                        access_mode     = "multi-node-multi-writer"
                        mount_options {
                                fs_type     = "ext4"
                        }
                }

                task "rhodecode-redis" {
                        driver = "docker"
                        volume_mount {
                                volume      = "rhodecode_data"
                                destination = "/var/opt/rhodecode_data"
                        }
                        config {
                                image = "${image}:${tag}"
                                ports = ["redis"]
                                mount {
                                        type   = "bind"
                                        target = "/var/log/rhodecode"
                                        source = "tmp"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                        }
                        resources {
                                cpu    = 300
                                memory = 1024
                        }
                        service {
                                name = "$\u007BNOMAD_JOB_NAME\u007D"
                                port = "redis"
                                check {
                                        name         = "alive"
                                        type         = "tcp"
                                        interval     = "30s"
                                        timeout      = "5s"
                                        failures_before_critical = 5
                                        port         = "redis"
                                }
                        }
                }
        }
}
