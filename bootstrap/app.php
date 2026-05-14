<?php

use Roots\Acorn\Application;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        wordpress: true,
    )
    ->boot();
