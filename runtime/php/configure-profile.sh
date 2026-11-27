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
}
$d["repositories"] = [["type"=>"path", "url"=>"/opt/open-loyalty-framework", "options"=>["symlink"=>false, "versions"=>[$name=>$version]]]];
file_put_contents($f, json_encode($d, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n");
$params="/var/www/openloyalty/app/config/parameters.yml";
$yaml=file_get_contents($params);
$yaml=str_replace("- elk:9200", "- search:9200", $yaml);
foreach (["8182"=>getenv("ADMIN_PATH"), "8183"=>getenv("CUSTOMER_PATH"), "8184"=>getenv("SELLER_PATH")] as $port=>$path) {
    $yaml=str_replace("http://localhost:".$port."/", "http://127.0.0.1/".$path, $yaml);
}
file_put_contents($params, $yaml);
$fw="/opt/open-loyalty-framework/composer.json";
$p=json_decode(file_get_contents($fw), true);
if (!is_array($p)) { fwrite(STDERR, "Invalid framework composer.json\n"); exit(1); }
$p["name"]=$name;
file_put_contents($fw, json_encode($p, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n");
'
cd /var/www/openloyalty
composer update "$APP_FRAMEWORK_PACKAGE" --no-scripts --no-interaction --prefer-dist --no-progress
composer install --no-scripts --no-interaction --prefer-dist --no-progress
