<?php

require_once "./vendor/autoload.php";
\Tina4\Initialize();
const TINA4_SUPPRESS = true;
require_once "./index.php";

(new \Tina4\GitDeploy())->doDeploy();