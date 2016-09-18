# nagios-selenium-grid-plugin

* This plugin uses the grid's console UI to extract busy and all sessions per browser type
* You can configure warn and critical levels using the `-w` and `-c` cli options, so if the busy precentage of at least one of the browser types being monitored exceed the limit it will be reflected in nagios
* You can remove of add browser types to this plugin, notice that if your browser types are not according to the default, you must change it.
* The plugin is already configured to work with nagiosgraph, so you can see the data in a visalize way overtime

## Usage 
```
  usage: ./check_selenium_grid.sh -u http://seleniumserver:port/grid/console [-w warning_percentage] [-c critical_precentage] [-t browser_types_to_check]
    -u  selenium grid console url
    -w  warn in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: 70
    -c  error in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: 95
    -t  browser types to check. We 'wc -l' the <browser_type>.png in the console to find all sessions and after that 'wc -l' class=busy for the busy ones. default is: chrome,firefox,internet_explorer
    -h  display help
```

## Adding it into Nagios
Add a command to nagios, for example:

```
define command {
  command_name selenium_grid_active_sessions
  command_line /DATA/gitrepo/nagios/Server/etc/objects/check_selenium_grid.sh -u $ARG1$ -w $ARG2$ -c $ARG3$ -t $ARG4$
}
```

Add a service to nagios in localhost.cfg, for example:
```
define service{
    use                         generic-service-with-notify
    host_name                   localhost
    service_description         Check Selenium Grid Active Sessions
    check_command               selenium_grid_active_sessions!http://nagios_server:4444/grid/console!70!95!chrome,firefox,internet_explorer
    check_interval              1
    contacts                    ci_admin
}
```

Restart nagios

You should see the new service under the localhost machine

watch the visulalized data in nagiosgraph
