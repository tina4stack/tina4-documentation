# How do I run a daemon service in Tina4

First start the tina4service
```
php bin\tina4service
```
Next you create your service class to run in the service

The pattern is simple
```php

class MyMonitorService extends \Tina4\Process implements \Tina4\ProcessInterface
{
    public function canRun(): bool
    {
        // TODO: Implement canRun() method.
    }

    /**
     * The code that will run when this process can run
     */
    public function run()
    {
        // TODO: Implement run() method.
    }

}
```

```
[Unit]
Description=Tina4Daemon
After=syslog.target
After=network.target

[Service]
WorkingDirectory=/path/to/document_root
ExecStart=/usr/bin/java -jar /home/metabase/metabase.jar
EnvironmentFile=/etc/default/metabase
User=metabase
Type=simple
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=metabase
SuccessExitStatus=143
TimeoutStopSec=120
Restart=always

[Install]
WantedBy=multi-user.target
```
https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
```bash
sudo systemctl enable uptimemonitor.service
```

```
sudo systemctl start uptimemonitor.service
```

```
sudo systemctl status uptimemonitor.service
```


```bash
sudo systemctl disable uptimemonitor.service
```
```dotenv
TINA4_SERVICE_TIME=5
```