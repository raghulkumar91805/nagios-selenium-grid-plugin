# nagios-selenium-grid-plugin

* This plugin uses the grid's console UI to extract busy and all sessions per browser type
* You can configure warn and critical levels using the `-w` and `-c` cli options, so if the busy precentage of at least one of the browser types being monitored exceed the limit it will be reflected in nagios
* You can remove of add browser types to this plugin, notice that if your browser types are not according to the default, you must change it.

## Usage 
```
  usage: ./check_selenium_grid.sh -u http://seleniumserver:port/grid/console [-w warning_percentage] [-c critical_precentage] [-t browser_types_to_check]
    -u  selenium grid console url
    -w  warn in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: 70
    -c  error in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: 95
    -t  browser types to check. We 'wc -l' the <browser_type>.png in the console to find all sessions and after that 'wc -l' class=busy for the busy ones. default is: chrome,firefox,internet_explorer
    -h  display help
```
