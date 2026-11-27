#!/bin/sh
set -eu
php -r '
$f="/var/www/openloyalty/composer.json";
$d=json_decode(file_get_contents($f), true);
if (!is_array($d)) { fwrite(STDERR, "Invalid application composer.json\n"); exit(1); }
$name=getenv("APP_FRAMEWORK_PACKAGE");
$version=getenv("APP_FRAMEWORK_VERSION");
if ($name === "sskur/open-loyalty-framework") {
    unset($d["require"]["dataworksbi/open-loyalty-framework"]);
    $d["require"][$name] = $version;
    $d["require"]["doctrine/cache"] = "1.13.0";
    $d["config"]["platform"]["php"] = "7.4.0";
}
$d["repositories"] = [["type"=>"path", "url"=>"/opt/open-loyalty-framework", "options"=>["symlink"=>false, "versions"=>[$name=>$version]]]];
file_put_contents($f, json_encode($d, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n");
$params="/var/www/openloyalty/app/config/parameters.yml";
$yaml=file_get_contents($params);
$yaml=str_replace("- elk:9200", "- search:9200", $yaml);
if ($name === "sskur/open-loyalty-framework") {
    $yaml=str_replace("parameters:\n", "parameters:\n    kernel.root_dir: /var/www/openloyalty/app\n", $yaml);
    $yaml=str_replace("jwt_private_key_path: %kernel.root_dir%/var/jwt/private.pem", "jwt_private_key_path: \"%kernel.root_dir%/var/jwt/private.pem\"", $yaml);
    $yaml=str_replace("jwt_public_key_path:  %kernel.root_dir%/var/jwt/public.pem", "jwt_public_key_path:  \"%kernel.root_dir%/var/jwt/public.pem\"", $yaml);
}
foreach (["8182"=>getenv("ADMIN_PATH"), "8183"=>getenv("CUSTOMER_PATH"), "8184"=>getenv("SELLER_PATH")] as $port=>$path) {
    $yaml=str_replace("http://localhost:".$port."/", "http://127.0.0.1/".$path, $yaml);
}
file_put_contents($params, $yaml);
$fw="/opt/open-loyalty-framework/composer.json";
$p=json_decode(file_get_contents($fw), true);
if (!is_array($p)) { fwrite(STDERR, "Invalid framework composer.json\n"); exit(1); }
$p["name"]=$name;
if ($name === "sskur/open-loyalty-framework") {
    $p["require"]["broadway/event-store-dbal"] = "0.5.0";
    $p["require"]["symfony/monolog-bundle"] = "^3.8";
    $p["require"]["symfony/swiftmailer-bundle"] = "^3.5";
    unset($p["require"]["doctrine/doctrine-cache-bundle"]);
    $kernel="/var/www/openloyalty/app/AppKernel.php";
    $source=file_get_contents($kernel);
    $source=str_replace("            new Doctrine\\Bundle\\DoctrineCacheBundle\\DoctrineCacheBundle(),\n", "", $source);
    $source=str_replace("            new OpenLoyalty\\Bundle\\PosBundle\\OpenLoyaltyPosBundle(),\n", "            new OpenLoyalty\\Bundle\\PosBundle\\OpenLoyaltyPosBundle(),\n            new OpenLoyalty\\Bundle\\NetworkBundle\\OpenLoyaltyNetworkBundle(),\n", $source);
    file_put_contents($kernel, $source);
    $config="/var/www/openloyalty/app/config/config.yml";
    $yaml=file_get_contents($config);
    $yaml=str_replace("knp_doctrine_behaviors:", "doctrine_behaviors:", $yaml);
    $yaml=str_replace("    templating:\n        engines: [".chr(39)."twig".chr(39)."]\n", "", $yaml);
    $yaml=str_replace("    routing_loader:\n        include_format: true\n        default_format: json\n", "    routing_loader: false\n", $yaml);
    $yaml=str_replace("nelmio_api_doc:\n    sandbox:\n        request_format:\n            method: accept_header\n", "", $yaml);
    file_put_contents($config, $yaml);
    $devFrontController="/var/www/openloyalty/web/app_dev.php";
    $source=file_get_contents($devFrontController);
    $source=str_replace("use Symfony\\Component\\Debug\\Debug;", "use Symfony\\Component\\ErrorHandler\\Debug;", $source);
    file_put_contents($devFrontController, $source);
    $deprecated="/var/www/openloyalty/app/config/services_deprecated.yml";
    $yaml=file_get_contents($deprecated);
    $yaml=str_replace("%service_id%", "%alias_id%", $yaml);
    file_put_contents($deprecated, $yaml);
    $security="/var/www/openloyalty/app/config/security.yml";
    $yaml=file_get_contents($security);
    $yaml=str_replace("lexik_jwt: ~", "jwt: ~", $yaml);
    $yaml=str_replace("security:\n", "security:\n    enable_authenticator_manager: true\n", $yaml);
    $yaml=str_replace("anonymous: true", "", $yaml);
    foreach (["seller_api"=>"^/api/seller", "customer_api"=>"^/api/customer", "admin_api"=>"^/api"] as $firewall=>$pattern) {
        $yaml=str_replace("        ".$firewall.":\n            pattern:   ".$pattern, "        ".$firewall.":\n            entry_point: oloy.user.guard.token\n            pattern:   ".$pattern, $yaml);
    }
    $yaml=str_replace("                entry_point: oloy.user.guard.token\n", "", $yaml);
    $yaml=str_replace("              entry_point: oloy.user.guard.token\n", "", $yaml);
    file_put_contents($security, $yaml);
    $prod="/var/www/openloyalty/app/config/config_prod.yml";
    $yaml=file_get_contents($prod);
    $yaml=str_replace("        metadata_cache_driver: apcu\n", "", $yaml);
    $yaml=str_replace("        result_cache_driver: apcu\n", "", $yaml);
    $yaml=str_replace("        query_cache_driver: apcu\n", "", $yaml);
    file_put_contents($prod, $yaml);
}
file_put_contents($fw, json_encode($p, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n");
'
cd /var/www/openloyalty
if [ "$APP_FRAMEWORK_PACKAGE" = "sskur/open-loyalty-framework" ]; then
    cp /tmp/profile-latest-composer.lock composer.lock
    composer install --no-scripts --no-interaction --prefer-dist --no-progress
else
    composer update "$APP_FRAMEWORK_PACKAGE" --no-scripts --no-interaction --prefer-dist --no-progress
    composer install --no-scripts --no-interaction --prefer-dist --no-progress
fi
