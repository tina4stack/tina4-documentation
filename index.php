<?php
require_once "./vendor/autoload.php";


$config = new \Tina4\Config(static function (\Tina4\Config $config){
    //Your own config initializations
});

//Hack to build css for documentation
$scss = new ScssPhp\ScssPhp\Compiler();
$scssDefault = $scss->compileString(file_get_contents("./src/templates/documentation/default.scss"))->getCss();
file_put_contents("./src/public/css/tina4-docs.css", $scssDefault);

\Tina4\Get::add("/", function (\Tina4\Response $response) {
    return $response(\Tina4\renderTemplate("documentation/index.twig"));
});



echo new \Tina4\Tina4Php($config);