<?php

declare(strict_types=1);

/*
 * DE: Gemeinsame Rector-Basis: PHP-Sets passend zur PHP-Version aus composer.json und Upgrade-Sets passend zu den
 *     installierten Symfony-/Doctrine-/PHPUnit-/Twig-Versionen. Die CI prüft nur (--dry-run); angewendet wird lokal
 *     mit `vendor/bin/symfony-standards fix`.
 *     Aufruf aus der rector.php des Projekts:
 *     return (require __DIR__.'/vendor/jostkleigrewe/symfony-standards/config/rector.php')(__DIR__);
 * EN: Shared Rector base (PHP sets from composer.json, composer-based framework sets), called with the project root.
 */

use Rector\Config\RectorConfig;
use Rector\Configuration\RectorConfigBuilder;

return static function (string $projectDir): RectorConfigBuilder {
    $paths = array_values(array_filter(
        [$projectDir.'/src', $projectDir.'/tests', $projectDir.'/config'],
        is_dir(...),
    ));

    return RectorConfig::configure()
        ->withPaths($paths)
        ->withSkip([
            $projectDir.'/config/bundles.php',
            $projectDir.'/config/reference.php',
        ])
        // DE: Cache außerhalb von var/ — im Container gehört var/ oft einem anderen User (arma-ai, 2026).
        // EN: Cache outside var/ — inside containers var/ is often owned by another uid.
        ->withCache(cacheDirectory: sprintf('%s/rector-%s', sys_get_temp_dir(), md5($projectDir)))
        ->withPhpSets()
        ->withComposerBased(twig: true, doctrine: true, phpunit: true, symfony: true)
        ->withAttributesSets();
};
