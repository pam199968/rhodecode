job "rhodecode-svn" {
        datacenters = ["${datacenter}"]
        type = "service"
        vault {
                policies = ["forge"]
                change_mode = "restart"
    }
        update {
                stagger = "30s"
                max_parallel = 1
        }

        group "rhodecode-svn" {
                count = "1"
                # install only on "data" nodes
                constraint {
                                attribute = "${node.class}"
                                value     = "data"
                }
                restart {
                                attempts = 3
                                delay = "60s"
                                interval = "1h"
                                mode = "fail"
                }
                network {
                                mode = "host"
                                port "webdav" { to = 8090 }
                }
                task "prep-disk" {
                        driver = "docker"
                        config {
                                image = "busybox:latest"
                                mount {
                                        type = "volume"
                                        target = "/etc/rhodecode/conf"
                                        source = "rh-conf"
                                        readonly = false
                                        volume_options {
                                                no_copy = false
                                                driver_config {
                                                        name = "pxd"
                                                        options {
                                                                io_priority = "high"
                                                                shared = true
                                                                size = 1
                                                                repl = 2
                                                        }
                                                }
                                        }
                                }
                                command = "sh"
                                args = ["-c", "mkdir -p /etc/rhodecode/conf/svn && touch /etc/rhodecode/conf/svn/mod_dav_svn.conf"]
                        }
                        resources {
                                cpu = 200
                                memory = 128
                        }
                        lifecycle {
                                hook = "prestart"
                                sidecar = "false"
                        }
                }
                task "rhodecode-svn" {
                        driver = "docker"
                        template {
                                data =<<EOT
RC_APP_TYPE="rhodecode_svn"
MOD_DAV_SVN_PORT=8090
APACHE_LOG_DIR="/var/log/rhodecode/svn"
MOD_DAV_SVN_CONF_FILE="/etc/rhodecode/conf/svn/mod_dav_svn.conf"
EOT
                                destination="secrets/file.env"
                                env = true
                        }
                        template {
                                data =<<EOT
LoadModule headers_module /usr/lib/apache2/modules/mod_headers.so
LoadModule authn_anon_module /usr/lib/apache2/modules/mod_authn_anon.so

<VirtualHost *:${MOD_DAV_SVN_PORT}>
    ServerAdmin admin@localhost
    DocumentRoot /var/opt/www
    ErrorLog ${APACHE_LOG_DIR}/svn_error.log
    CustomLog ${APACHE_LOG_DIR}/svn_access.log combined
    LogLevel info

    <Location /_server_status>
        SetHandler server-status
        Allow from all
    </Location>

    # allows custom host names, prevents 400 errors on checkout
    HttpProtocolOptions Unsafe

    Include ${MOD_DAV_SVN_CONF_FILE}
</VirtualHost>
EOT
                                destination = "local/virtualhost.conf"
                        }
                        config {
                                image = "${image}:${tag}"
                                command = "apachectl"
                                args = [
                                                "-D",
                                                "FOREGROUND"
                                        ]
                                ports = ["webdav"]
                                mount {
                                        type = "volume"
                                        target = "/var/opt/rhodecode_repo_store"
                                        source = "rh-repos"
                                        readonly = false
                                        volume_options {
                                                no_copy = false
                                                driver_config {
                                                        name = "pxd"
                                                        options {
                                                                io_priority = "high"
                                                                shared = true
                                                                size = 100
                                                                repl = 2
                                                        }
                                                }
                                        }
                                }
                                mount {
                                        type = "volume"
                                        target = "/etc/rhodecode/conf"
                                        source = "rh-conf"
                                        readonly = false
                                        volume_options {
                                                no_copy = false
                                                driver_config {
                                                        name = "pxd"
                                                        options {
                                                                        io_priority = "high"
                                                                        shared = true
                                                                        size = 20
                                                                        repl = 2
                                                                        }
                                                                }
                                                        }
                                                }
                                mount {
                                        type = "bind"
                                        target = "/var/log/rhodecode/svn"
                                        source = "tmp"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                                mount {
                                        type = "bind"
                                        target = "/etc/apache2/sites-enabled/virtualhost.conf"
                                        source = "local/virtualhost.conf"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                        }
                        resources {
                                        cpu = 200
                                        memory = 512
                        }
                        service {
                                name = "${NOMAD_JOB_NAME}"
                                port = "webdav"
                                tags = [ "urlprefix-svn/" ]
                                check {
                                        name         = "alive"
                                        type         = "tcp"
                                        interval     = "10s"
                                        timeout      = "2s"
                                        port         = "webdav"
                                }
                        }
                }
        }
}
