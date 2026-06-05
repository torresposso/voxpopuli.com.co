<?php

namespace App\Tests;

use PHPUnit\Framework\TestCase;
use Brain\Monkey;

class FunctionsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
    }

    protected function tearDown(): void
    {
        Monkey\tearDown();
        parent::tearDown();
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testMissingAutoloader()
    {
        Monkey\Functions\expect('__')
            ->once()
            ->with('Error: Please run <code>composer install</code> in the theme directory.', 'sage')
            ->andReturn('Translated error message');

        Monkey\Functions\expect('wp_die')
            ->once()
            ->with('Translated error message')
            ->andThrow(new \Exception('wp_die called'));

        // Redefine file_exists to return false specifically for the vendor/autoload.php file
        \Patchwork\redefine('file_exists', function ($file) {
            if (strpos($file, 'vendor/autoload.php') !== false) {
                return false;
            }
            return \Patchwork\relay();
        });

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('wp_die called');

        require __DIR__ . '/../functions.php';
    }
}
