# Services and Processes
::: tip 🔥 Hot Tips
- Run code at regular intervals - note this is not clock based so timings are not exact.
- There is one service runner for all registered processes.
- "Cron style" timings are available.
  :::

## Operation overview
The Tina4 services feature, only available in PHP, provides a cron like feature to run services at regular intervals.

A service runner, found in `bin/tina4service` is registered on the server, with a systemd service unit file to run as a
background service. It uses the processes registered in the `bin/services.data` file. Any advanced timing is saved in the 
`bin/servicesLastTime.data` file.

Steps to creating a working service
* Create the needed processes
* Add processes to the service.
* Register the service on the server

## Creating a process
All processes extend the `Tina4\Process` interface and require
* The name, used to reference the process, 
* a function to decide if the process can run during that service run
* and the actual run function.
```php
class MyProcess extends \Tina4\Process
{
    public $name = "MY NEW PROCESS";

    public function canRun(): bool
    {
        // Code to decide if the process can run
        
        return true;
    }

    public function run(): void
    {
        // Code that runs
    }
}
```
## Adding and Removing processes
Processes can be added or removed from the service runner anywhere in your `php` code.
```php
$service = (new \Tina4\Service());

// Removing an old process
$service->removeProcess("MY OLD PROCESS")

// This adds the process to the services.data file
$process = new MyProcess("MY NEW PROCESS");
$service->addProcess($process);
```

## Register the service on a server
This process may differ depending on your server setup, but the file should look something like this.
```
[Unit]
Description=Example Service for Documentation
After=mysqld.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=3
User=myServerUser
WorkingDirectory=/home/myServerUser/public_html
ExecStart=php bin/tina4service

[Install]
WantedBy=multi-user.target
```
The use of the bash commands `systemctl` and `journalctl`, to control the service, are outside the scope of this document.

## Simple timings
It is important to note that the service runner uses a pause timer between runs. This means that the time taken to run all 
the processes is also added to the pause timer to give the true time between runs. This natually will vary from run to run.

The default pause time is 5 seconds, but this can be overwritten in the `.env` file
```
TINA4_SERVICE_TIME=30
```
## Advanced timings
Advanced "cron style" timings are available and need to be declared when the process is added to the service runner.
```php
/*
 * "minute hour day month weekday"
 *  Accepts wild card '*' - runs on every timing
 *  Accepts interval '*\/5' - runs every 5 units of timing. Note backslash not included is an escape here
 *  Accepts list '1,4,34,57' - runs every given unit of timing
 *  Accepts value '3' - runs on the given unit of timing
*/
$service->addProcess(new MyProcess("MY ADVANCED PROCESS", "* * 1 * *"));
```
::: warning Notes of Caution
- NOTE: This does not replace the sleep timer which still is in effect. These timings act as a wrapper on the `canRun()` method,
to determine if it is time to run yet.
- CAUTION: For this to work adequately the services sleep timer should probably be set to less than 50 seconds to avoid missing timed runs
- CAUTION: This should never be used for accurate timing as it could be upto TINA4_SERVICE_TIME seconds delayed. Remember it checks if the time to run has passed, not a specific time
:::

## Efficiency and Strategy

It is important to remember that there is a single service runner that runs all of the processes and then sleeps for the  `TINA_SERVICE_TIME`.
Implications to this are that if one of the processes fails, all subsequent processes are not run for that cycle. Recurring failures would 
effectively shut down the subsequent processes. 

As each process runs one after the other, numerous lengthy processes should be avoided so that each
service run is not significantly delayed.

To combat this, combining processes with [Threads](threads.md) helps to mitigate this issue, where the only thing the process does is
spin up a new thread to handle the process requirements.

```php
class MyProcess extends \Tina4\Process
{
    public $name = "MY NEW PROCESS";

    public function canRun(): bool
    {
        // Using the presence of a simple lock file to counter race conditions
        if (file_exists("bin/my-process.lock")){
            return false;
        } else {
            return true;
        }
    }

    public function run(): void
    {
        \Tina4\Thread::trigger('MyProcessThread');
    }
}
```

::: warning Race conditions
- If each service run for a process, requires the last one to be finished, then some kind of race condition protection is required. The above example uses the presence of a lock file to achieve this.
  :::