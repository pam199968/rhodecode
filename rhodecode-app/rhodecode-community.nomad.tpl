job "rhodecode-community" {
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

        group "rhodecode-server" {
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
                                port "rhodecode" { to = 10020 }
                                port "vcsserver" { to = 10010 }
                }
                task "rhodecode" {
                        artifact {
                                source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/rhodecode/rcextensions.zip"
                                destination = "local"
                        }

                        driver = "docker"
                        template {
                                data =<<EOT
exec /var/opt/rhodecode_bin/bin/gunicorn --name=gunicorn-rhodecode-1 --error-logfile=- --paster=/local/rhodecode.optimized.ini --config=/etc/rhodecode/conf_build/gunicorn_conf.py &
exec /home/rhodecode/.rccontrol/vcsserver-1/profile/bin/gunicorn --name=gunicorn-vcsserver-1 --error-logfile=- --paster=/local/vcsserver.optimized.ini --config=/etc/rhodecode/conf_build/gunicorn_conf.py
EOT
                                destination = "local/run.sh"
                        }
                        template {
                                data =<<EOT

TZ="UTC"
RC_APP_TYPE="rhodecode_http"
SSL_CERT_FILE="/etc/rhodecode/conf_build/ca-bundle.crt"
REQUESTS_CA_BUNDLE="/etc/rhodecode/conf_build/ca-bundle.crt"
GIT_SSL_CAINFO="/etc/rhodecode/conf_build/ca-bundle.crt"
GEVENT_RESOLVER="ares"
DB_UPGRADE=1
SETUP_APP=0
MAIN_INI_PATH="/local/rhodecode.optimized.ini"
EOT
                                destination="secrets/file.env"
                                env = true
                        }
                        template {
                                data = <<EOT
; #################################
; RHODECODE VCSSERVER CONFIGURATION
; #################################
[server:main]
host = 0.0.0.0
port = 10010

; ###########################
; GUNICORN APPLICATION SERVER
; ###########################
use = egg:gunicorn#main

; Sets the number of process workers. More workers means more concurrent connections
; RhodeCode can handle at the same time. Each additional worker also it increases
; memory usage as each has it's own set of caches.
; Recommended value is (2 * NUMBER_OF_CPUS + 1), eg 2CPU = 5 workers, but no more
; than 8-10 unless for really big deployments .e.g 700-1000 users.
; `instance_id = *` must be set in the [app:main] section below (which is the default)
; when using more than 1 worker.
workers = 3

; Gunicorn access log level
loglevel = info

; Process name visible in process list
proc_name = gunicorn-vcsserver-1

; Type of worker class, one of `sync`, `gevent`
; currently `sync` is the only option allowed.
worker_class = sync

; The maximum number of simultaneous clients. Valid only for gevent
worker_connections = 10

; Max number of requests that worker will handle before being gracefully restarted.
; Prevents memory leaks, jitter adds variability so not all workers are restarted at once.
max_requests = 3000
max_requests_jitter = 100

; Amount of time a worker can spend with handling a request before it
; gets killed and restarted. By default set to 21600 (6hrs)
; Examples: 1800 (30min), 3600 (1hr), 7200 (2hr), 43200 (12h)
timeout = 21600

; The maximum size of HTTP request line in bytes.
; 0 for unlimited
limit_request_line = 0

; Limit the number of HTTP headers fields in a request.
; By default this value is 100 and can't be larger than 32768.
limit_request_fields = 32768

; Limit the allowed size of an HTTP request header field.
; Value is a positive number or 0.
; Setting it to 0 will allow unlimited header field sizes.
limit_request_field_size = 0

; Timeout for graceful workers restart.
; After receiving a restart signal, workers have this much time to finish
; serving requests. Workers still alive after the timeout (starting from the
; receipt of the restart signal) are force killed.
; Examples: 1800 (30min), 3600 (1hr), 7200 (2hr), 43200 (12h)
graceful_timeout = 3600

# The number of seconds to wait for requests on a Keep-Alive connection.
# Generally set in the 1-5 seconds range.
keepalive = 2

; Maximum memory usage that each worker can use before it will receive a
; graceful restart signal 0 = memory monitoring is disabled
; Examples: 268435456 (256MB), 536870912 (512MB)
; 1073741824 (1GB), 2147483648 (2GB), 4294967296 (4GB)
memory_max_usage = 2147483648

; How often in seconds to check for memory usage for each gunicorn worker
memory_usage_check_interval = 60

; Threshold value for which we don't recycle worker if GarbageCollection
; frees up enough resources. Before each restart we try to run GC on worker
; in case we get enough free memory after that, restart will not happen.
memory_usage_recovery_threshold = 0.8


[app:main]
; The %(here)s variable will be replaced with the absolute path of parent directory
; of this file
use = egg:rhodecode-vcsserver

; Pyramid default locales, we need this to be set
pyramid.default_locale_name = en

; default locale used by VCS systems
locale = en_US.UTF-8

; path to binaries for vcsserver, it should be set by the installer
; at installation time, e.g /home/user/vcsserver-1/profile/bin
; it can also be a path to nix-build output in case of development
core.binary_dir = /home/rhodecode/.rccontrol/vcsserver-1/profile/bin

; Custom exception store path, defaults to TMPDIR
; This is used to store exception from RhodeCode in shared directory
#exception_tracker.store_path =

; #############
; DOGPILE CACHE
; #############

; Default cache dir for caches. Putting this into a ramdisk can boost performance.
; eg. /tmpfs/data_ramdisk, however this directory might require large amount of space
cache_dir = /var/opt/rhodecode_data

; ***************************************
; `repo_object` cache, default file based
; ***************************************

; `repo_object` cache settings for vcs methods for repositories
#rc_cache.repo_object.backend = dogpile.cache.rc.file_namespace

; cache auto-expires after N seconds
; Examples: 86400 (1Day), 604800 (7Days), 1209600 (14Days), 2592000 (30days), 7776000 (90Days)
#rc_cache.repo_object.expiration_time = 2592000

; file cache store path. Defaults to `cache_dir =` value or tempdir if both values are not set
#rc_cache.repo_object.arguments.filename = /tmp/vcsserver_cache.db

; ***********************************************************
; `repo_object` cache with redis backend
; recommended for larger instance, and for better performance
; ***********************************************************

; `repo_object` cache settings for vcs methods for repositories
rc_cache.repo_object.backend = dogpile.cache.rc.redis_msgpack

; cache auto-expires after N seconds
; Examples: 86400 (1Day), 604800 (7Days), 1209600 (14Days), 2592000 (30days), 7776000 (90Days)
rc_cache.repo_object.expiration_time = 2592000

; redis_expiration_time needs to be greater then expiration_time
rc_cache.repo_object.arguments.redis_expiration_time = 3592000

rc_cache.repo_object.arguments.host = {{ range service "rhodecode-redis" }}{{ .Address }}{{ end }}
rc_cache.repo_object.arguments.port = {{ range service "rhodecode-redis" }}{{ .Port }}{{ end }}
rc_cache.repo_object.arguments.db = 5
rc_cache.repo_object.arguments.socket_timeout = 30
; more Redis options: https://dogpilecache.sqlalchemy.org/en/latest/api.html#redis-backends
#rc_cache.repo_object.arguments.distributed_lock = true


; #####################
; LOGGING CONFIGURATION
; #####################
[loggers]
keys = root, vcsserver

[handlers]
keys = console

[formatters]
keys = generic

; #######
; LOGGERS
; #######
[logger_root]
level = NOTSET
handlers = console

[logger_vcsserver]
level = DEBUG
handlers =
qualname = vcsserver
propagate = 1


; ########
; HANDLERS
; ########

[handler_console]
class = StreamHandler
args = (sys.stderr, )
level = INFO
formatter = generic

; ##########
; FORMATTERS
; ##########

[formatter_generic]
format = %(asctime)s.%(msecs)03d [%(process)d] %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %Y-%m-%d %H:%M:%S
EOT
                                destination = "local/vcsserver.optimized.ini"
                        }
                        template {
                                data = <<EOT
; ##########################################
; RHODECODE ENTERPRISE EDITION CONFIGURATION
; ##########################################
[DEFAULT]
; Debug flag sets all loggers to debug, and enables request tracking
debug = true

########################################################################
; EMAIL CONFIGURATION
; These settings will be used by the RhodeCode mailing system
########################################################################
#email_prefix = [RhodeCode]
#app_email_from = rhodecode-noreply@localhost
#smtp_server = mail.server.com
#smtp_username =
#smtp_password =
#smtp_port =
#smtp_use_tls = false
#smtp_use_ssl = true

[server:main]
; COMMON HOST/IP CONFIG
host = 0.0.0.0
port = 10020
; ###########################
; GUNICORN APPLICATION SERVER
; ###########################
use = egg:gunicorn#main
workers = 2
loglevel = info
proc_name = gunicorn-web-1
worker_class = gevent
worker_connections = 10
max_requests = 2000
max_requests_jitter = 100
timeout = 21600
limit_request_line = 0
limit_request_fields = 32768
limit_request_field_size = 0
graceful_timeout = 3600
keepalive = 2
memory_max_usage = 2147483648
memory_usage_check_interval = 60
memory_usage_recovery_threshold = 0.8
[filter:proxy-prefix]
use = egg:PasteDeploy#prefix
prefix = /rhodecode
[app:main]
use = egg:rhodecode-enterprise-ce
filter-with = proxy-prefix
gzip_responses = false
generate_js_files = false
lang = fr
startup.import_repos = false
archive_cache_dir = /etc/rhodecode/conf/data/tarballcache
app.base_url = {{ with secret "forge/rhodecode/app" }}{{ .Data.data.rc_base_url }}{{end}}
app_instance_uuid = 4442f2dac4dc4fb982f781546735bb99
cut_off_limit_diff = 512000
cut_off_limit_file = 128000
vcs_full_cache = true
force_https = false
use_htsts = false
git_update_server_info = false
rss_cut_off_limit = 256000
rss_items_per_page = 10
rss_include_diff = false
gist_alias_url =
api_access_controllers_whitelist =
default_encoding = UTF-8
instance_id =
auth_plugin.import_legacy_plugins = true
auth_ret_code =
auth_ret_code_detection = false
lock_ret_code = 423
allow_repo_location_change = true
allow_custom_hooks_settings = true
license_token = abra-cada-bra1-rce3
license.hide_license_info = false
supervisor.uri = 127.0.0.1:10001
supervisor.group_id = web-1
labs_settings_active = true
file_store.enabled = true
file_store.backend = local
file_store.storage_path = /var/opt/rhodecode_data/file_store
; #############
; CELERY CONFIG
; #############
use_celery = true
celery.broker_url = {{ range service "rhodecode-redis" }}redis://{{ .Address }}:{{ .Port }}/8{{ end }}
celery.max_tasks_per_child = 20
celery.task_always_eager = false
cache_dir = /var/opt/rhodecode_data
rc_cache.sql_cache_short.backend = dogpile.cache.rc.memory_lru
rc_cache.sql_cache_short.expiration_time = 30
rc_cache.cache_repo_longterm.backend = dogpile.cache.rc.memory_lru
rc_cache.cache_repo_longterm.expiration_time = 2592000
rc_cache.cache_repo_longterm.max_size = 10000
rc_cache.cache_perms.backend = dogpile.cache.rc.redis
rc_cache.cache_perms.expiration_time = 300
rc_cache.cache_perms.arguments.redis_expiration_time = 7200
rc_cache.cache_perms.arguments.host = {{ range service "rhodecode-redis" }}{{ .Address }}{{ end }}
rc_cache.cache_perms.arguments.port = {{ range service "rhodecode-redis" }}{{ .Port }}{{ end }}
rc_cache.cache_perms.arguments.db = 0
rc_cache.cache_perms.arguments.socket_timeout = 30
rc_cache.cache_repo.backend = dogpile.cache.rc.redis
rc_cache.cache_repo.expiration_time = 2592000
rc_cache.cache_repo.arguments.host = {{ range service "rhodecode-redis" }}{{ .Address }}{{ end }}
rc_cache.cache_repo.arguments.port = {{ range service "rhodecode-redis" }}{{ .Port }}{{ end }}
rc_cache.cache_repo.arguments.db = 1
rc_cache.cache_repo.arguments.socket_timeout = 30
; ##############
; BEAKER SESSION
; ##############

beaker.session.type = ext:redis
beaker.session.url = {{ range service "rhodecode-redis" }}redis://{{ .Address }}:{{ .Port }}/2{{ end }}
beaker.session.key = http_app
beaker.session.secret = b39acb28b2304a27a6a0e911500bf7d1
beaker.session.lock_dir = /data_ramdisk/lock
beaker.session.timeout = 2592000
beaker.session.httponly = true
beaker.session.secure = false
; #############################
; SEARCH INDEXING CONFIGURATION
; #############################
search.module = rhodecode.lib.index.whoosh
search.location = /var/opt/rhodecode_data/index
; ####################
; CHANNELSTREAM CONFIG
; ####################
channelstream.enabled = false
channelstream.server = channelstream:9800
channelstream.ws_url = ws:/localhost:8888/_channelstream
channelstream.secret = b39acb28b2304a27a6a0e911500bf7d1
channelstream.history.location = /var/opt/rhodecode_data/channelstream_history
channelstream.proxy_path = /_channelstream
chat.enabled = false
; ##############################
; MAIN RHODECODE DATABASE CONFIG
; ##############################
sqlalchemy.db1.url = {{ with secret "forge/rhodecode/postgres" }}postgresql://{{ .Data.data.postgres_user }}:{{ .Data.data.postgres_pass }}@{{ range service "rhodecode-postgres" }}{{ .Address }}:{{ .Port }}{{ end }}/rhodecode{{ end }}
sqlalchemy.db1.echo = false
sqlalchemy.db1.pool_recycle = 3600
sqlalchemy.db1.convert_unicode = true
; ##########
; VCS CONFIG
; ##########
vcs.server.enable = true
vcs.start_server = false
;vcs.server = {{ range service "rhodecode-vcsserver" }}{{ .Address }}:{{ .Port }}{{ end }}
vcs.server = 127.0.0.1:10010
vcs.server.protocol = http
vcs.scm_app_implementation = http
vcs.hooks.protocol = http
; Host on which this instance is listening for hooks. If vcsserver is in other location, this should be adjuste
vcs.hooks.host = 127.0.0.1
vcs.hooks.direct_calls = false
;vcs.hooks.host = {{ env "NOMAD_ADDR_rhodecode" }}
vcs.backends = git, svn
vcs.connection_timeout = 3600
svn.proxy.generate_config = true
svn.proxy.list_parent_path = true
svn.proxy.config_file_path = /etc/rhodecode/conf/svn/mod_dav_svn.conf
svn.proxy.location_root = /
; ####################
; SSH Support Settings
; ####################
ssh.generate_authorized_keyfile = true
ssh.authorized_keys_file_path = /etc/rhodecode/conf/ssh/authorized_keys_rhodecode
ssh.wrapper_cmd = /var/opt/rhodecode_bin/bin/rc-ssh-wrapper
ssh.wrapper_cmd_allow_shell = false
ssh.enable_debug_logging = false
ssh.executable.hg = ~/.rccontrol/vcsserver-1/profile/bin/hg
ssh.executable.git = ~/.rccontrol/vcsserver-1/profile/bin/git
ssh.executable.svn = ~/.rccontrol/vcsserver-1/profile/bin/svnserve
ssh.enable_ui_key_generator = true
custom.conf = 1
; #####################
; LOGGING CONFIGURATION
; #####################
[loggers]
keys = root, sqlalchemy, beaker, celery, rhodecode, ssh_wrapper, vcsserver

[handlers]
keys = console, console_sql

[formatters]
keys = generic, color_formatter, color_formatter_sql
; #######
; LOGGERS
; #######

[logger_root]
level = DEBUG
handlers = console

[logger_sqlalchemy]
level = INFO
handlers = console_sql
qualname = sqlalchemy.engine
propagate = 0

[logger_beaker]
level = DEBUG
handlers =
qualname = beaker.container
propagate = 1

[logger_rhodecode]
level = DEBUG
handlers = console
qualname = rhodecode
propagate = 1

[logger_ssh_wrapper]
level = DEBUG
handlers =
qualname = ssh_wrapper
propagate = 1

[logger_celery]
level = DEBUG
handlers =
qualname = celery

[logger_vcsserver]
level = DEBUG
handlers = console
qualname = vcsserver-


; ########
; HANDLERS
; ########

[handler_console]
class = StreamHandler
args = (sys.stderr, )
level = DEBUG
formatter = generic

[handler_console_sql]
class = StreamHandler
args = (sys.stderr, )
level = WARN
formatter = generic

; ##########
; FORMATTERS
; ##########

[formatter_generic]
class = rhodecode.lib.logging_formatter.ExceptionAwareFormatter
format = %(asctime)s.%(msecs)03d [%(process)d] %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %Y-%m-%d %H:%M:%S

[formatter_color_formatter]
class = rhodecode.lib.logging_formatter.ColorFormatter
format = %(asctime)s.%(msecs)03d [%(process)d] %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %Y-%m-%d %H:%M:%S

[formatter_color_formatter_sql]
class = rhodecode.lib.logging_formatter.ColorFormatterSql
format = %(asctime)s.%(msecs)03d [%(process)d] %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %Y-%m-%d %H:%M:%S
EOT
                                destination = "local/rhodecode.optimized.ini"
                        }
                        config {
                                image = "${image}:${tag}"
                                extra_hosts = [ "svn:${NOMAD_IP_rhodecode}" ]
                                command = "sh"
                                args = [ "/local/run.sh" ]
                                ports = ["rhodecode", "vcsserver"]
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
                                                shared = "v4"
                                                size = 10
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
                                                shared = "v4"
                                                size = 1
                                                repl = 2
                                          }
                                        }
                                  }
                                }
                                mount {
                                  type = "volume"
                                  target = "/var/opt/rhodecode_data"
                                  source = "rh-data"
                                  readonly = false
                                  volume_options {
                                        no_copy = false
                                        driver_config {
                                          name = "pxd"
                                          options {
                                                io_priority = "high"
                                                shared = "v4"
                                                size = 10
                                                repl = 2
                                          }
                                        }
                                  }
                                }
                                mount {
                                        type = "tmpfs"
                                        target = "/data_ramdisk"
                                        readonly = false
                                        tmpfs_options {
                                                size = 100000
                                        }
                                }
                                mount {
                                        type = "bind"
                                        target = "/var/log/rhodecode"
                                        source = "tmp"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                        }
                        resources {
                                        cpu = 1024
                                        memory = 7168
                        }
                        service {
                                name = "${NOMAD_TASK_NAME}-http"
                                tags = ["urlprefix-/rhodecode"]
                                port = "rhodecode"
                                check {
                                        name         = "rhodecode-alive"
                                        type         = "http"
                                        path              = "_admin/ops/ping"
                                        interval     = "60s"
                                        timeout      = "30s"
                                        port         = "rhodecode"
                                }
                        }
                        service {
                                name = "${NOMAD_JOB_NAME}-vcsserver"
                                port = "vcsserver"
                                check {
                                        name         = "vcsserver-alive"
                                        type         = "http"
                                        path              = "/status"
                                        interval     = "60s"
                                        timeout      = "30s"
                                        port         = "vcsserver"
                                }
                        }
                }
        }
}

