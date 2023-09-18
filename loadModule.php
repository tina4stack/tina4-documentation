<?php

use Twig\TwigFunction;

\Tina4\Module::addModule("Documentation Module", "1.0.0", "tina4documentation", static function (\Tina4\Config $config) {
    //do something here specific with documentation ...
    $config->addTwigFunction("include_code",  function($fileName) {
        $fileName = "./src/templates/documentation/".$fileName;
        if (file_exists($fileName)) {
            return file_get_contents($fileName);
        }

        return "";
    });
});