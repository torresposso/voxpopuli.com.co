<?php

/*
|--------------------------------------------------------------------------
| Register The Auto Loader
|--------------------------------------------------------------------------
|
| Composer provides a convenient, automatically generated class loader for
| our theme. We will simply require it into the script here so that we
| don't have to worry about manually loading any of our classes later on.
|
*/

if (! file_exists($composer = __DIR__.'/vendor/autoload.php')) {
    wp_die(__('Error: Please run <code>composer install</code> in the theme directory.', 'sage'));
}

require_once $composer;

/*
|--------------------------------------------------------------------------
| Boot Acorn
|--------------------------------------------------------------------------
|
| Acorn provides a bootstrapper for the theme. We will simply require it
| here to ensure that the theme is loaded properly.
|
*/

if (! function_exists('\Roots\bootloader')) {
    wp_die(__('Error: Acorn is not installed or available.', 'sage'));
}

\Roots\bootloader()->boot();
