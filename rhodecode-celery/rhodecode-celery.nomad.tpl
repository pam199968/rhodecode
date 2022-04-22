job "rhodecode-celery" {
        datacenters = ["${datacenter}"]
        type = "service"
        update {
                stagger = "30s"
                max_parallel = 1
        }

        group "rhodecode-celery" {
                count = "1"
                # install only on "data" nodes
                constraint {
                                attribute = "$\u007Bnode.class\u007D"
                                value     = "data"
                }
                restart {
                                attempts = 3
                                delay = "60s"
                                interval = "1h"
                                mode = "fail"
                }
                task "rhodecode-celery" {
                        driver = "docker"
                        template {
                                data = <<EOT
RC_APP_TYPE="rhodecode_celery"
RC_APP_PROC=1
SSL_CERT_FILE="/etc/rhodecode/conf/ca-bundle.crt"
REQUESTS_CA_BUNDLE="/etc/rhodecode/conf/ca-bundle.crt"
GIT_SSL_CAINFO="/etc/rhodecode/conf/ca-bundle.crt"
MAIN_INI_PATH="/secrets/rhodecode.optimized.ini"
EOT
                                destination="secrets/file.env"
                                env = true
                        }
                        template {
                                data = <<EOT
; ##########################################
; RHODECODE ENTERPRISE EDITION CONFIGURATION
; ##########################################
[DEFAULT]
; Debug flag sets all loggers to debug, and enables request tracking
debug = false
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
vcs.server = {{ range service "rhodecode-vcsserver" }}{{ .Address }}:{{ .Port }}{{ end }}
vcs.server.protocol = http
vcs.scm_app_implementation = http
vcs.hooks.protocol = http
; Host on which this instance is listening for hooks. If vcsserver is in other location, this should be adjusted.
vcs.hooks.host = {{ range service "rhodecode-vcsserver" }}{{ .Address }}:{{ .Port }}{{ end }}
vcs.start_server = false
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
keys = root, sqlalchemy, beaker, celery, rhodecode, ssh_wrapper

[handlers]
keys = console, console_sql

[formatters]
keys = generic, color_formatter, color_formatter_sql
; #######
; LOGGERS
; #######

[logger_root]
level = NOTSET
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
handlers =
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

; ########
; HANDLERS
; ########

[handler_console]
class = StreamHandler
args = (sys.stderr, )
level = INFO
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
                                destination = "secrets/rhodecode.optimized.ini"

                        }
                        config {
                                image = "${image}:${tag}"
                                command = "/var/opt/rhodecode_bin/bin/celery"
                                args = [
                                                "worker",
                                                "--task-events",
                                                "--autoscale=10,2",
                                                "--no-color",
                                                "--app=rhodecode.lib.celerylib.loader",
                                                "--loglevel=DEBUG",
                                                "--ini=/secrets/rhodecode.optimized.ini"
                                                ]
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
										type = "volume"
										target = "/var/opt/rhodecode_repo_store"
										source = "rhodecode-repos"
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
                                        target = "/var/log/rhodecode"
                                        source = "tmp"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                        }
                        resources {
                                cpu = 100
                                memory = 512
                        }
                }
        }
}
