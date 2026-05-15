<?php

namespace Tests;

use PHPUnit\Framework\TestCase;
use RuntimeException;

class ApplicationConfigTest extends TestCase
{
    private string $tempDir;
    private string $envFile;
    private string $applicationConfigFile;

    protected function setUp(): void
    {
        $this->tempDir = sys_get_temp_dir() . '/bedrock_test_' . uniqid();
        mkdir($this->tempDir);

        $this->envFile = $this->tempDir . '/.env';

        // Copy the application.php to our temp directory so it runs with $root_dir as tempDir
        mkdir($this->tempDir . '/config');
        mkdir($this->tempDir . '/web');

        $sourceConfig = file_get_contents(dirname(__DIR__) . '/config/application.php');
        file_put_contents($this->tempDir . '/config/application.php', $sourceConfig);
        $this->applicationConfigFile = $this->tempDir . '/config/application.php';
    }

    protected function tearDown(): void
    {
        if (file_exists($this->envFile)) {
            unlink($this->envFile);
        }
        if (file_exists($this->tempDir . '/config/application.php')) {
            unlink($this->tempDir . '/config/application.php');
        }
        if (is_dir($this->tempDir . '/config')) {
            rmdir($this->tempDir . '/config');
        }
        if (is_dir($this->tempDir . '/web')) {
            rmdir($this->tempDir . '/web');
        }
        if (is_dir($this->tempDir)) {
            rmdir($this->tempDir);
        }
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testLoadsDotenvAndRequiredVariablesSuccessfully()
    {
        $envContent = <<<ENV
WP_HOME=http://example.com
WP_SITEURL=http://example.com/wp
DB_NAME=test_db
DB_USER=test_user
DB_PASSWORD=test_pass
ENV;
        file_put_contents($this->envFile, $envContent);

        // This should not throw any exceptions
        require $this->applicationConfigFile;

        $this->assertSame('http://example.com', \Roots\WPConfig\Config::get('WP_HOME'));
        $this->assertSame('test_db', \Roots\WPConfig\Config::get('DB_NAME'));
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testThrowsExceptionWhenMissingWpHome()
    {
        $envContent = <<<ENV
WP_SITEURL=http://example.com/wp
DB_NAME=test_db
DB_USER=test_user
DB_PASSWORD=test_pass
ENV;
        file_put_contents($this->envFile, $envContent);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('WP_HOME');

        require $this->applicationConfigFile;
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testRequiresDatabaseVariablesWhenNoUrlOrSqlite()
    {
        $envContent = <<<ENV
WP_HOME=http://example.com
WP_SITEURL=http://example.com/wp
DB_NAME=test_db
# Missing DB_USER and DB_PASSWORD
ENV;
        file_put_contents($this->envFile, $envContent);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('DB_USER');

        require $this->applicationConfigFile;
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testDoesNotRequireDatabaseVariablesWhenDatabaseUrlIsSet()
    {
        $envContent = <<<ENV
WP_HOME=http://example.com
WP_SITEURL=http://example.com/wp
DATABASE_URL=mysql://user:pass@host/db
ENV;
        file_put_contents($this->envFile, $envContent);

        // This should not throw any exceptions
        require $this->applicationConfigFile;

        $this->assertSame('db', \Roots\WPConfig\Config::get('DB_NAME'));
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testDoesNotRequireDatabaseVariablesWhenDbEngineIsSqlite()
    {
        $envContent = <<<ENV
WP_HOME=http://example.com
WP_SITEURL=http://example.com/wp
DB_ENGINE=sqlite
ENV;
        file_put_contents($this->envFile, $envContent);

        // This should not throw any exceptions
        require $this->applicationConfigFile;

        // Verify WP_HOME is set to confirm file ran successfully
        $this->assertSame('http://example.com', \Roots\WPConfig\Config::get('WP_HOME'));
    }
}
