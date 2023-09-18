<?php

use Twig\TwigFunction;

\Tina4\Module::addModule("Documentation Module", "1.0.0", "tina4documentation", static function (\Tina4\Config $config) {

    //Deploy the SCSS for the documentation
    $scss = new ScssPhp\ScssPhp\Compiler();
    $scssDefault = $scss->compileString(file_get_contents(__DIR__."/src/templates/documentation/default.scss"))->getCss();
    file_put_contents("./src/public/css/tina4-docs.css", $scssDefault);

    $config->addTwigFunction("include_code",  function($fileName) {
        $fileName = __DIR__."/src/templates/documentation/".$fileName;
        if (file_exists($fileName)) {
            return file_get_contents($fileName);
        }

        return "";
    });
});