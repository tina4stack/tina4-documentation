# Services

Tina4 supports a synchronous process queue system. The service is easily run from the command line or a daemon service.
Processes can be registered and removed from anywhere in your process code or from a web applicatioin running on the
same server. Process timing can be set simply in the .env or with more advanced linux style cron timing notifications.

## The service runner

The service runner ```tina4service``` usually resides in ```bin``` folder in the root of the project. Once it has loaded
the Tina4 environment, it then enters a continuous loop with the important following steps

- Creates a new service object
- Engages a sleep timer, the default timing
- Gets all the active processes
- For each process
  - It loads the process
  - Checks for advanced timing
  - Checks for any conditions that would stop the process from running
  - If all good, then runs the process

!!! tip "Service and Process hot tips"
    - As the service loads the Tina4 environment before entering the loop, any changes to the Tina4 code requires a service restart.
    - As the loop creates a new service object and new process objects, no variables can be persisted in the loop on the service or process objects.
    - Any process code changed while a service is running should reload on the next run

## Starting the service runner - command line
The service can be started simply from the command line when in the project folder

```php bin/tina4service```

Tina4 also has a composer script for the same thing

```composer start-service```

## Stopping the service runner - command line
There are occasions when the service runner needs to be stopped in code or from the command line. This is simply achieved by 
placing an empty file named ```stop``` in the folder where the tina4service is being run. While often done from the command line,
this could also be done in the process or application code.

## Controlling the service runner - daemon service
To run the service as a linux daemon service, one first needs to create the daemon class file and save it the appropriate server daemon folder.
```
[Unit]
Description=Tina4Service MyService
After=mysqld.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=3
User=serveruser
WorkingDirectory=/home/serveruser/public_html
ExecStart=php bin/tina4service

[Install]
WantedBy=multi-user.target
```

This file saved as ```myservice.service``` creates a service runner that should restart after server shutdown, after the mysql
service has started. The following commands are often used on the server for controlling the runner.

```bash
systemctl start myservice.service
systemctl stop myservice.service
systemctl restart myservice.service
systemctl status myservice.service
```

For a more in depth view on linux services please consult 
<a href="https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units" target="_blank" rel="noopener noreferrer">this helpful tutorial by DigitalOcean</a>

## Creating the process

Each process class must consist of at least the following two functions. Each service runner can run multiple processes.
```php
class MyProcess extends \Tina4\Process implements \Tina4\ProcessInterface
{
    /**
     * Code to decide if the process can run. 
     * This should not be timing related but functionality related
     * See below for timing control  
     */
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

## Adding the process to the service runner

Processes can be added to the service runner from any code, be it in a webhook, another class, even in another process.
An instantiated Process object is given to the service addProcess function. This adds the process information to a file
```services.data``` which resides in the ```bin``` folder.

```php
$process = (new MyProcess("Process Call Name"))

$service = (new \Tina4\Service());
$service->addProcess($process);
```

## Removing the process from the service runner
Processes that are removed as below, are removed from the ```services.data```
```php
$service = (new \Tina4\Service());
$service->removeProcess("Process Call Name");
```

## Services timing - default

The default wait time between each service run is set at 5 seconds. This can be overwritten in the ```.env``` file
```dotenv
TINA4_SERVICE_TIME=5
```

## Services timing - advanced

Due to the default timing being set for the entire service, all processes run after each other once the sleep timer is passed.
This makes process level timing impossible. From version 2.0.82 linux style cron timing has been introduced and can be set when
instantiating the process.
```php
// runs approximately every 2 hours
$process = (new MyProcess("Process Call Name", "* 2 * * *"));
```

The timing string is set as follows

```
minute hour day month weekday

// Accepts wild card '*' - runs on every timing
// Accepts interval '*/5' - runs every 5 units of timing
// Accepts list '1,4,34,57' - runs every given unit of timing
// Accepts value '3' - runs on the given unit of timing
```

As the service runner can attempt to run a process, more than once in an advanced timing setting, it keeps track of the last
timed run in the ```servicesLastTime.data``` file to avoid duplications.

!!! tip "Timing hot tips"
    - Should the default service timing be set at greater than 60 seconds, it might result in missed runs due to the sleep timer being longer than the advanced timing.
    - It is important to note that these advance timings are approximate, with an error equal to the default timer and the time it takes to run all the processes in the service.
    - To avoid large delays on service processes, one can combine services with triggers, to keep the process time short and let the trigger deal with the delay of the code being run.

!!! danger
    Should precise timing be required, it is probably better to look at using server based cron mechanisms.