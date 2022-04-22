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

                task "rhodecode-redis" {
                        driver = "docker"
                        config {
                                image = "${image}:${tag}"
                                ports = ["redis"]
								mount {
										type = "volume"
										target = "/var/opt/rhodecode_data"
										source = "rhodecode-data"
										readonly = false
										volume_options {
												no_copy = false
												driver_config {
														name = "pxd"
														options {
																io_priority = "high"
																size = 1
																repl = 2
														}
												}
										}
								}
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
