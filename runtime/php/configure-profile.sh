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
    $compatDirectory="/var/www/openloyalty/app/var/reference-compat";
    if (!is_dir($compatDirectory)) { mkdir($compatDirectory, 0775, true); }
    $compatFile=$compatDirectory."/doctrine-persistence.php";
    file_put_contents($compatFile, "<?php\nnamespace Doctrine\\Common\\Persistence;\ninterface ObjectRepository extends \\Doctrine\\Persistence\\ObjectRepository {}\n");
    if (!in_array($compatFile, $d["autoload"]["files"] ?? [], true)) { $d["autoload"]["files"][]=$compatFile; }
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
    $directory=new RecursiveIteratorIterator(new RecursiveDirectoryIterator("/opt/open-loyalty-framework/src/OpenLoyalty/Bundle"));
    foreach ($directory as $file) {
        if (!$file->isFile() || $file->getFilename() !== "Configuration.php") { continue; }
        $source=file_get_contents($file->getPathname());
        $rootMarker="$"."treeBuilder->root(";
        $rootStart=strpos($source, $rootMarker);
        if ($rootStart === false) {
            $source=str_replace("new TreeBuilder();", "new TreeBuilder(\"open_loyalty_user\");", $source);
            file_put_contents($file->getPathname(), $source);
            continue;
        }
        $quote=chr(39);
        $rootNameStart=strpos($source, $quote, $rootStart + strlen($rootMarker));
        $rootNameEnd=strpos($source, $quote, $rootNameStart + 1);
        if ($rootNameStart === false || $rootNameEnd === false) { continue; }
        $rootName=substr($source, $rootNameStart + 1, $rootNameEnd - $rootNameStart - 1);
        $source=str_replace("new TreeBuilder();", "new TreeBuilder(\"".$rootName."\");", $source);
        $source=str_replace($rootMarker.$quote.$rootName.$quote.")", "$"."treeBuilder->getRootNode()", $source);
        file_put_contents($file->getPathname(), $source);
    }
    $serviceFiles=new RecursiveIteratorIterator(new RecursiveDirectoryIterator("/opt/open-loyalty-framework/src"));
    foreach ($serviceFiles as $file) {
        if (!$file->isFile() || $file->getExtension() !== "yml") { continue; }
        $source=file_get_contents($file->getPathname());
        $source=str_replace("        scope: prototype\n", "        shared: false\n", $source);
        $source=str_replace("!php/const:OpenLoyalty\\Component\\Core\\Domain\\SystemEvent\\LogoSystemEvents::RESIZED_LOGO_EVENT", "oloy.logo.resized", $source);
        $source=str_replace("!php/const:OpenLoyalty\\Component\\Campaign\\Domain\\Event\\CampaignPhotoSavedEvent::NAME", "oloy.campaign.photo.saved", $source);
        $source=str_replace("!php/const:OpenLoyalty\\Component\\Campaign\\Domain\\Event\\CampaignPhotoRemovedEvent::NAME", "oloy.campaign.photo.removed", $source);
        $source=str_replace(chr(39)."@templating".chr(39), chr(39)."@twig".chr(39), $source);
        file_put_contents($file->getPathname(), $source);
    }
    $translationTraits=[
        "/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/TranslationBundle/Model/FallbackTranslatable.php"=>[
            "TranslatableProperties"=>"TranslatablePropertiesTrait",
            "TranslatableMethods"=>"TranslatableMethodsTrait"
        ],
        "/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/TranslationBundle/Model/FallbackTranslation.php"=>[
            "TranslationProperties"=>"TranslationPropertiesTrait",
            "TranslationMethods"=>"TranslationMethodsTrait"
        ]
    ];
    foreach ($translationTraits as $path=>$traits) {
        $source=file_get_contents($path);
        foreach ($traits as $oldTrait=>$newTrait) {
            $source=str_replace("\\".$oldTrait.";", "\\".$newTrait.";", $source);
            $source=str_replace("use ".$oldTrait.",", "use ".$newTrait.",", $source);
            $source=str_replace("        ".$oldTrait.";", "        ".$newTrait.";", $source);
        }
        file_put_contents($path, $source);
    }
    $translationContracts=[
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Level/Domain/Level.php", "Level", "TranslatableInterface"],
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Campaign/Domain/Campaign.php", "Campaign", "TranslatableInterface"],
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Campaign/Domain/CampaignCategory.php", "CampaignCategory", "TranslatableInterface"],
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Level/Domain/LevelTranslation.php", "LevelTranslation", "TranslationInterface"],
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Campaign/Domain/CampaignTranslation.php", "CampaignTranslation", "TranslationInterface"],
        ["/opt/open-loyalty-framework/src/OpenLoyalty/Component/Campaign/Domain/CampaignCategoryTranslation.php", "CampaignCategoryTranslation", "TranslationInterface"]
    ];
    foreach ($translationContracts as $contract) {
        $source=file_get_contents($contract[0]);
        $source=str_replace("class ".$contract[1]."\n", "class ".$contract[1]." implements \\Knp\\DoctrineBehaviors\\Contract\\Entity\\".$contract[2]."\n", $source);
        file_put_contents($contract[0], $source);
    }
    $compilerPass="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/TranslationBundle/DependencyInjection/Compiler/KnpDefaultLocaleCompilerPass.php";
    $source=file_get_contents($compilerPass);
    $serviceName="knp.doctrine_behaviors.translatable_subscriber.default_locale_callable";
    $source=str_replace("        $"."definition = $"."container->getDefinition(".chr(39).$serviceName.chr(39).");", "        if (!$"."container->hasDefinition(".chr(39).$serviceName.chr(39).")) { return; }\n        $"."definition = $"."container->getDefinition(".chr(39).$serviceName.chr(39).");", $source);
    file_put_contents($compilerPass, $source);
    $eventStore="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/CoreBundle/EventStore/ConcurrencyDBALEventStore.php";
    $source=file_get_contents($eventStore);
    $dollar=chr(36);
    $method="public function append(".$dollar."id, DomainEventStream ".$dollar."uncommittedEvents)";
    $source=str_replace($method, $method.": void", $source);
    $visit="public function visitEvents(Criteria ".$dollar."criteria, EventVisitor ".$dollar."eventVisitor)";
    $old=$visit."\n    {\n        return ".$dollar."this->visitEvents(".$dollar."criteria, ".$dollar."eventVisitor);\n    }";
    $new=$visit.": void\n    {\n        ".$dollar."this->eventStore->visitEvents(".$dollar."criteria, ".$dollar."eventVisitor);\n    }";
    $source=str_replace($old, $new, $source);
    $oldTyped=$visit.": void\n    {\n        ".$dollar."this->visitEvents(".$dollar."criteria, ".$dollar."eventVisitor);\n    }";
    $source=str_replace($oldTyped, $new, $source);
    file_put_contents($eventStore, $source);
    $adminHandler="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/UserBundle/CQRS/Handler/AdminHandler.php";
    $source=file_get_contents($adminHandler);
    $source=str_replace("public function handle(\$command)", "public function handle(\$command): void", $source);
    foreach (["handleCreateAdmin", "handleEditAdmin", "handleSelfEditAdmin"] as $handler) {
        $source=str_replace("return \$this->".$handler."(\$command);", "\$this->".$handler."(\$command);", $source);
    }
    file_put_contents($adminHandler, $source);
    $repository="/opt/open-loyalty-framework/src/OpenLoyalty/Component/Core/Infrastructure/Repository/SnapshottingEventSourcingRepository.php";
    $source=file_get_contents($repository);
    $source=str_replace("public function save(AggregateRoot \$aggregate)", "public function save(AggregateRoot \$aggregate): void", $source);
    file_put_contents($repository, $source);
    $phpFiles=new RecursiveIteratorIterator(new RecursiveDirectoryIterator("/opt/open-loyalty-framework/src"));
    foreach ($phpFiles as $file) {
        if (!$file->isFile() || $file->getExtension() !== "php") { continue; }
        if (strpos($file->getPathname(), "/Tests/") !== false) { continue; }
        $source=file_get_contents($file->getPathname());
        $handleSignature="public function handle(DomainMessage \$domainMessage)";
        $source=str_replace($handleSignature."\n    {", $handleSignature.": void\n    {", $source);
        $source=str_replace("FOS\\RestBundle\\Controller\\FOSRestController", "FOS\\RestBundle\\Controller\\AbstractFOSRestController", $source);
        $source=str_replace("extends FOSRestController", "extends AbstractFOSRestController", $source);
        $source=str_replace("Symfony\\Component\\HttpKernel\\Event\\GetResponseEvent", "Symfony\\Component\\HttpKernel\\Event\\RequestEvent", $source);
        $source=str_replace("Symfony\\Component\\HttpKernel\\Event\\GetResponseForExceptionEvent", "Symfony\\Component\\HttpKernel\\Event\\ExceptionEvent", $source);
        $source=str_replace("Symfony\\Component\\Translation\\TranslatorInterface", "Symfony\\Contracts\\Translation\\TranslatorInterface", $source);
        $source=str_replace("use Symfony\\Component\\Form\\FormFactory;", "use Symfony\\Component\\Form\\FormFactoryInterface;", $source);
        $source=str_replace("FormFactory ".$dollar, "FormFactoryInterface ".$dollar, $source);
        $source=str_replace("GetResponseEvent", "RequestEvent", $source);
        $source=str_replace("GetResponseForExceptionEvent", "ExceptionEvent", $source);
        if (strpos($source, "use Twig_Environment;") !== false) {
            $source=str_replace("use Symfony\\Bridge\\Twig\\TwigEngine;\n", "", $source);
            $source=str_replace("use Twig_Environment;", "use Twig\\Environment;", $source);
        } else {
            $source=str_replace("use Symfony\\Bridge\\Twig\\TwigEngine;", "use Twig\\Environment;", $source);
        }
        $source=str_replace("TwigEngine", "Environment", $source);
        $source=str_replace("Twig_Environment", "Environment", $source);
        $source=str_replace("$"."this->twigEngine->exists(", "$"."this->twigEngine->getLoader()->exists(", $source);
        if ($file->getFilename() === "CSVGenerator.php") {
            $source=str_replace("PropertyAccessor", "PropertyAccessorInterface", $source);
        }
        if ($file->getFilename() === "CheckboxTypeExtension.php") {
            $source=str_replace("    public function getExtendedType()", "    public static function getExtendedTypes(): iterable\n    {\n        return [CheckboxType::class];\n    }\n\n    public function getExtendedType()", $source);
        }
        file_put_contents($file->getPathname(), $source);
    }
    $role="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/UserBundle/Entity/Role.php";
    $source=file_get_contents($role);
    $source=str_replace("use Symfony\\Component\\Security\\Core\\Role\\RoleInterface;\n", "", $source);
    $source=str_replace("class Role implements RoleInterface", "class Role", $source);
    file_put_contents($role, $source);
    $authListener="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/UserBundle/EventListener/AuthenticationListener.php";
    $source=file_get_contents($authListener);
    $source=str_replace("use Symfony\\Component\\Security\\Core\\Role\\RoleInterface;\n", "", $source);
    $source=str_replace("function (RoleInterface \$role)", "function (\$role)", $source);
    file_put_contents($authListener, $source);
    rename("/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/NetworkBundle/Security/Voter/PosVoter.php", "/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/NetworkBundle/Security/Voter/NetworkVoter.php");
    $authenticator="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/UserBundle/Security/Authenticator/TokenAuthenticator.php";
    $source=file_get_contents($authenticator);
    $source=str_replace("    public function start(Request \$request, AuthenticationException \$authException = null)", "    public function supports(Request \$request)\n    {\n        return null !== \$this->getCredentials(\$request);\n    }\n\n    public function start(Request \$request, AuthenticationException \$authException = null)", $source);
    file_put_contents($authenticator, $source);
    $config="/var/www/openloyalty/app/config/config.yml";
    $yaml=file_get_contents($config);
    $yaml=str_replace("knp_doctrine_behaviors:", "doctrine_behaviors:", $yaml);
    $yaml=str_replace("    templating:\n        engines: [".chr(39)."twig".chr(39)."]\n", "", $yaml);
    $yaml=str_replace("    routing_loader:\n        include_format: true\n        default_format: json\n", "    routing_loader: false\n", $yaml);
    $yaml=str_replace("nelmio_api_doc:\n    sandbox:\n        request_format:\n            method: accept_header\n", "", $yaml);
    $yaml=str_replace("        json:\n", "        json_serialization:\n", $yaml);
    $yaml=str_replace("doctrine_migrations:\n    namespace: OpenLoyalty\\Migrations\n", "doctrine_migrations:\n    migrations_paths:\n        ".chr(39)."OpenLoyalty\\Migrations".chr(39).": \"%kernel.project_dir%/app/DoctrineMigrations\"\n", $yaml);
    file_put_contents($config, $yaml);
    $services="/var/www/openloyalty/app/config/services.yml";
    $yaml=file_get_contents($services);
    $mapper="    OpenLoyalty\\Bundle\\CoreBundle\\CSVGenerator\\Mapper:\n";
    $alias="    OpenLoyalty\\Bundle\\CoreBundle\\CSVGenerator\\MapperInterface: ".chr(39)."@OpenLoyalty\\Bundle\\CoreBundle\\CSVGenerator\\Mapper".chr(39)."\n\n";
    if (strpos($yaml, "OpenLoyalty\\Bundle\\CoreBundle\\CSVGenerator\\MapperInterface:") === false) {
        $yaml=str_replace($mapper, $alias.$mapper, $yaml);
    }
    $status="    OpenLoyalty\\Component\\Customer\\Domain\\Model\\Status: ~\n\n";
    if (strpos($yaml, "OpenLoyalty\\Component\\Customer\\Domain\\Model\\Status:") === false) {
        $yaml=str_replace($mapper, $status.$mapper, $yaml);
    }
    $entityManager="    Doctrine\\ORM\\EntityManager: ".chr(39)."@doctrine.orm.entity_manager".chr(39)."\n";
    if (strpos($yaml, "Doctrine\\ORM\\EntityManager:") === false) {
        $yaml=str_replace($mapper, $entityManager.$mapper, $yaml);
    }
    $commandBus="    Broadway\\CommandHandling\\SimpleCommandBus: ".chr(39)."@broadway.command_handling.command_bus".chr(39)."\n";
    if (strpos($yaml, "Broadway\\CommandHandling\\SimpleCommandBus:") === false) {
        $yaml=str_replace($mapper, $commandBus.$mapper, $yaml);
    }
    $logoEvents="    OpenLoyalty\\Component\\Core\\Domain\\SystemEvent\\LogoSystemEvents: ~\n";
    if (strpos($yaml, "OpenLoyalty\\Component\\Core\\Domain\\SystemEvent\\LogoSystemEvents:") === false) {
        $yaml=str_replace($mapper, $logoEvents.$mapper, $yaml);
    }
    $photoEvents="    OpenLoyalty\\Component\\Core\\Domain\\SystemEvent\\PhotoSystemEvents: ~\n";
    if (strpos($yaml, "OpenLoyalty\\Component\\Core\\Domain\\SystemEvent\\PhotoSystemEvents:") === false) {
        $yaml=str_replace($mapper, $photoEvents.$mapper, $yaml);
    }
    $languageInterface="OpenLoyalty\\Component\\Translation\\Domain\\LanguageRepository";
    if (strpos($yaml, $languageInterface.":") === false) {
        $languageService="    ".$languageInterface.": ".chr(39)."@OpenLoyalty\\Component\\Translation\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineLanguageRepository".chr(39)."\n";
        $languageRepository="    OpenLoyalty\\Component\\Translation\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineLanguageRepository:\n        factory: [".chr(39)."@doctrine.orm.entity_manager".chr(39).", getRepository]\n        arguments: [".chr(39)."OpenLoyalty\\Component\\Translation\\Domain\\Language".chr(39)."]\n\n";
        $yaml=str_replace($mapper, $languageService.$languageRepository.$mapper, $yaml);
    }
    $aclInterface="OpenLoyalty\\Bundle\\UserBundle\\Service\\AclManagerInterface";
    if (strpos($yaml, $aclInterface.":") === false) {
        $aclAlias="    ".$aclInterface.": ".chr(39)."@OpenLoyalty\\Bundle\\UserBundle\\Service\\AclManager".chr(39)."\n";
        $yaml=str_replace($mapper, $aclAlias.$mapper, $yaml);
    }
    $levelRepository="OpenLoyalty\\Component\\Level\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineLevelRepository";
    if (strpos($yaml, $levelRepository.":") === false) {
        $levelAlias="    ".$levelRepository.": ".chr(39)."@oloy.level.repository".chr(39)."\n";
        $yaml=str_replace($mapper, $levelAlias.$mapper, $yaml);
    }
    $paramManager="OpenLoyalty\\Bundle\\UserBundle\\Service\\ParamManager";
    if (strpos($yaml, $paramManager.":") === false) {
        $paramManagerAlias="    ".$paramManager.": ".chr(39)."@oloy.user.param_manager".chr(39)."\n";
        $yaml=str_replace($mapper, $paramManagerAlias.$mapper, $yaml);
    }
    $customerStatusProvider="OpenLoyalty\\Bundle\\UserBundle\\Status\\CustomerStatusProvider";
    if (strpos($yaml, $customerStatusProvider.":") === false) {
        $customerStatusAlias="    ".$customerStatusProvider.": ".chr(39)."@oloy.customer_status_provider".chr(39)."\n";
        $yaml=str_replace($mapper, $customerStatusAlias.$mapper, $yaml);
    }
    $userManager="OpenLoyalty\\Bundle\\UserBundle\\Service\\UserManager";
    if (strpos($yaml, $userManager.":") === false) {
        $userManagerAlias="    ".$userManager.": ".chr(39)."@oloy.user.user_manager".chr(39)."\n";
        $yaml=str_replace($mapper, $userManagerAlias.$mapper, $yaml);
    }
    $messageFactoryInterface="OpenLoyalty\\Bundle\\EmailBundle\\Service\\MessageFactoryInterface";
    if (strpos($yaml, $messageFactoryInterface.":") === false) {
        $messageFactoryAlias="    ".$messageFactoryInterface.": ".chr(39)."@OpenLoyalty\\Bundle\\EmailBundle\\Service\\MessageFactory".chr(39)."\n";
        $yaml=str_replace($mapper, $messageFactoryAlias.$mapper, $yaml);
    }
    $customerProvider="OpenLoyalty\\Bundle\\UserBundle\\Service\\CustomerProvider";
    if (strpos($yaml, $customerProvider.":") === false) {
        $customerProviderAlias="    ".$customerProvider.": ".chr(39)."@oloy.user.customer_provider".chr(39)."\n";
        $yaml=str_replace($mapper, $customerProviderAlias.$mapper, $yaml);
    }
    $uuidGeneratorInterface="Broadway\\UuidGenerator\\UuidGeneratorInterface";
    if (strpos($yaml, $uuidGeneratorInterface.":") === false) {
        $uuidGeneratorAlias="    ".$uuidGeneratorInterface.": ".chr(39)."@broadway.uuid.generator".chr(39)."\n";
        $yaml=str_replace($mapper, $uuidGeneratorAlias.$mapper, $yaml);
    }
    $levelIdProvider="OpenLoyalty\\Component\\Customer\\Domain\\LevelIdProvider";
    if (strpos($yaml, $levelIdProvider.":") === false) {
        $levelIdProviderAlias="    ".$levelIdProvider.": ".chr(39)."@OpenLoyalty\\Bundle\\UserBundle\\Service\\OloyLevelIdProvider".chr(39)."\n";
        $yaml=str_replace($mapper, $levelIdProviderAlias.$mapper, $yaml);
    }
    $roleRepositoryInterface="OpenLoyalty\\Bundle\\UserBundle\\Entity\\Repository\\RoleRepositoryInterface";
    if (strpos($yaml, $roleRepositoryInterface.":") === false) {
        $roleRepositoryAlias="    ".$roleRepositoryInterface.": ".chr(39)."@OpenLoyalty\\Bundle\\UserBundle\\Entity\\Repository\\RoleRepository".chr(39)."\n";
        $yaml=str_replace($mapper, $roleRepositoryAlias.$mapper, $yaml);
    }
    $paramFetcher="FOS\\RestBundle\\Request\\ParamFetcher";
    if (strpos($yaml, $paramFetcher.":") === false) {
        $paramFetcherAlias="    ".$paramFetcher.": ".chr(39)."@fos_rest.request.param_fetcher".chr(39)."\n";
        $yaml=str_replace($mapper, $paramFetcherAlias.$mapper, $yaml);
    }
    $esParamManager="OpenLoyalty\\Bundle\\UserBundle\\Service\\EsParamManager";
    if (strpos($yaml, $esParamManager.":") === false) {
        $esParamManagerAlias="    ".$esParamManager.": ".chr(39)."@oloy.user.es_param_manager".chr(39)."\n";
        $yaml=str_replace($mapper, $esParamManagerAlias.$mapper, $yaml);
    }
    $accountProviderInterface="OpenLoyalty\\Bundle\\PointsBundle\\Import\\AccountProviderInterface";
    if (strpos($yaml, $accountProviderInterface.":") === false) {
        $accountProviderAlias="    ".$accountProviderInterface.": ".chr(39)."@OpenLoyalty\\Bundle\\PointsBundle\\Import\\AccountProvider".chr(39)."\n";
        $yaml=str_replace($mapper, $accountProviderAlias.$mapper, $yaml);
    }
    $pointsTransferManagerInterface="OpenLoyalty\\Component\\Account\\Infrastructure\\PointsTransferManagerInterface";
    if (strpos($yaml, $pointsTransferManagerInterface.":") === false) {
        $pointsTransferManagerAlias="    ".$pointsTransferManagerInterface.": ".chr(39)."@OpenLoyalty\\Bundle\\PointsBundle\\Service\\PointsTransfersManager".chr(39)."\n";
        $yaml=str_replace($mapper, $pointsTransferManagerAlias.$mapper, $yaml);
    }
    $levelRepositoryInterface="OpenLoyalty\\Component\\Level\\Domain\\LevelRepository";
    if (strpos($yaml, $levelRepositoryInterface.":") === false) {
        $levelRepositoryInterfaceAlias="    ".$levelRepositoryInterface.": ".chr(39)."@oloy.level.repository".chr(39)."\n";
        $yaml=str_replace($mapper, $levelRepositoryInterfaceAlias.$mapper, $yaml);
    }
    $tierAssignTypeProvider="OpenLoyalty\\Component\\Customer\\Infrastructure\\TierAssignTypeProvider";
    if (strpos($yaml, $tierAssignTypeProvider.":") === false) {
        $tierAssignTypeProviderAlias="    ".$tierAssignTypeProvider.": ".chr(39)."@oloy.user.settings_based_tier_assign_type_provider".chr(39)."\n";
        $yaml=str_replace($mapper, $tierAssignTypeProviderAlias.$mapper, $yaml);
    }
    $excludeDeliveryCostsProvider="OpenLoyalty\\Component\\Customer\\Infrastructure\\ExcludeDeliveryCostsProvider";
    if (strpos($yaml, $excludeDeliveryCostsProvider.":") === false) {
        $excludeDeliveryCostsProviderAlias="    ".$excludeDeliveryCostsProvider.": ".chr(39)."@oloy.user.settings_based_exclude_delivery_costs_provider".chr(39)."\n";
        $yaml=str_replace($mapper, $excludeDeliveryCostsProviderAlias.$mapper, $yaml);
    }
    $legacyTranslatorClass="Symfony\\Component\\Translation\\Translator";
    if (strpos($yaml, $legacyTranslatorClass.":") === false) {
        $legacyTranslatorAlias="    ".$legacyTranslatorClass.": ".chr(39)."@translator".chr(39)."\n";
        $yaml=str_replace($mapper, $legacyTranslatorAlias.$mapper, $yaml);
    }
    $posRepositoryInterface="OpenLoyalty\\Component\\Pos\\Domain\\PosRepository";
    if (strpos($yaml, $posRepositoryInterface.":") === false) {
        $posRepositoryAlias="    ".$posRepositoryInterface.": ".chr(39)."@oloy.pos.repository".chr(39)."\n";
        $yaml=str_replace($mapper, $posRepositoryAlias.$mapper, $yaml);
    }
    $earningRuleRepositoryInterface="OpenLoyalty\\Component\\EarningRule\\Domain\\EarningRuleRepository";
    if (strpos($yaml, $earningRuleRepositoryInterface.":") === false) {
        $earningRuleRepositoryAlias="    ".$earningRuleRepositoryInterface.": ".chr(39)."@oloy.earning_rule.repository".chr(39)."\n";
        $yaml=str_replace($mapper, $earningRuleRepositoryAlias.$mapper, $yaml);
    }
    $accountActivationMethod="OpenLoyalty\\Component\\Customer\\Domain\\Model\\AccountActivationMethod";
    if (strpos($yaml, $accountActivationMethod.":") === false) {
        $accountActivationMethodDefinition="    ".$accountActivationMethod.": ~\n";
        $yaml=str_replace($mapper, $accountActivationMethodDefinition.$mapper, $yaml);
    }
    $emailProvider="OpenLoyalty\\Bundle\\UserBundle\\Service\\EmailProvider";
    if (strpos($yaml, $emailProvider.":") === false) {
        $emailProviderAlias="    ".$emailProvider.": ".chr(39)."@oloy.user.email_provider".chr(39)."\n";
        $yaml=str_replace($mapper, $emailProviderAlias.$mapper, $yaml);
    }
    $campaignEditFormHandler="OpenLoyalty\\Bundle\\CampaignBundle\\Form\\Handler\\CampaignEditFormHandler";
    if (strpos($yaml, $campaignEditFormHandler.":") === false) {
        $campaignEditFormHandlerDefinition="    ".$campaignEditFormHandler.": ~\n";
        $yaml=str_replace($mapper, $campaignEditFormHandlerDefinition.$mapper, $yaml);
    }
    $campaignCategoryRepositoryInterface="OpenLoyalty\\Component\\Campaign\\Domain\\CampaignCategoryRepository";
    if (strpos($yaml, $campaignCategoryRepositoryInterface.":") === false) {
        $campaignCategoryRepositoryAlias="    ".$campaignCategoryRepositoryInterface.": ".chr(39)."@OpenLoyalty\\Component\\Campaign\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineCampaignCategoryRepository".chr(39)."\n";
        $campaignCategoryRepositoryService="    OpenLoyalty\\Component\\Campaign\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineCampaignCategoryRepository:\n        factory: [".chr(39)."@doctrine.orm.entity_manager".chr(39).", getRepository]\n        arguments: [".chr(39)."OpenLoyalty\\Component\\Campaign\\Domain\\CampaignCategory".chr(39)."]\n\n";
        $yaml=str_replace($mapper, $campaignCategoryRepositoryAlias.$campaignCategoryRepositoryService.$mapper, $yaml);
    }
    $campaignRepositoryInterface="OpenLoyalty\\Component\\Campaign\\Domain\\CampaignRepository";
    if (strpos($yaml, $campaignRepositoryInterface.":") === false) {
        $campaignRepositoryAlias="    ".$campaignRepositoryInterface.": ".chr(39)."@OpenLoyalty\\Component\\Campaign\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineCampaignRepository".chr(39)."\n";
        $campaignRepositoryService="    OpenLoyalty\\Component\\Campaign\\Infrastructure\\Persistence\\Doctrine\\Repository\\DoctrineCampaignRepository:\n        factory: [".chr(39)."@doctrine.orm.entity_manager".chr(39).", getRepository]\n        arguments: [".chr(39)."OpenLoyalty\\Component\\Campaign\\Domain\\Campaign".chr(39)."]\n\n";
        $yaml=str_replace($mapper, $campaignRepositoryAlias.$campaignRepositoryService.$mapper, $yaml);
    }
    file_put_contents($services, $yaml);
    foreach (["/var/www/openloyalty/web/app_dev.php", "/var/www/openloyalty/web/app.php", "/var/www/openloyalty/bin/console"] as $frontController) {
        $source=file_get_contents($frontController);
        $source=str_replace("use Symfony\\Component\\Debug\\Debug;", "use Symfony\\Component\\ErrorHandler\\Debug;", $source);
        $source=str_replace("$"."kernel->loadClassCache();\n", "", $source);
        file_put_contents($frontController, $source);
    }
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
php -r '
$listener="/opt/open-loyalty-framework/src/OpenLoyalty/Bundle/UserBundle/EventListener/AuthenticationListener.php";
$source=file_get_contents($listener);
$dollar=chr(36);
$dispatch="            ".$dollar."this->dispatcher->dispatch(\n                CustomerSystemEvents::CUSTOMER_LOGGED_IN,\n                [new CustomerLoggedInSystemEvent(new CustomerId(".$dollar."user->getId()))]\n            );";
$guarded="            if (".$dollar."user instanceof Customer) {\n".$dispatch."\n            }";
if (strpos($source, $guarded) === false) {
    if (strpos($source, $dispatch) === false) { fwrite(STDERR, "Customer login event hook not found\n"); exit(1); }
    $source=str_replace($dispatch, $guarded, $source);
    file_put_contents($listener, $source);
}
'
cd /var/www/openloyalty
if [ "$APP_FRAMEWORK_PACKAGE" = "sskur/open-loyalty-framework" ]; then
    cp /tmp/profile-latest-composer.lock composer.lock
    composer install --no-scripts --no-interaction --prefer-dist --no-progress
else
    composer update "$APP_FRAMEWORK_PACKAGE" --no-scripts --no-interaction --prefer-dist --no-progress
    composer install --no-scripts --no-interaction --prefer-dist --no-progress
fi
