########################################################################################################################
##
## CustomScriptExecution.Tests.ps1
##
##          The purpose of this script is to perform the unit testing for the CustomScriptExecution Module using Pester.
##          The script will import the CustomScriptExecution Module and any dependency moduels to perform the tests.
##
########################################################################################################################
$rootPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$scriptPath = Join-Path $rootPath -ChildPath '..' -AdditionalChildPath  @("..", "OrchestrationService", "CustomScriptExecution.ps1");
$scriptBlock = ". $scriptPath";
$script = [scriptblock]::Create($scriptBlock);
. $script;

Describe  "Custom Script Execution Unit Test Cases" {

    Context "Custom Script Execution" {

        It "Should execute a PowerShell Script" {

            $scriptPath = Join-Path $rootPath -ChildPath '..' -AdditionalChildPath  @("Samples", "scripts", "sample-script.ps1");

            $command = $scriptPath;

            $arguments = @{
                "SecondParameter" = "pwsh-script-test"
            }

            # Initialize the script prior to execution
            $customScriptExecutor = `
            [CustomScriptExecution]::new(
                $command, 
                $arguments
            );

            # Execute the script by calling Execute method
            $customScriptExecutor.Execute();

            $customScriptExecutor.Result | Should Be "pwsh-script-test";
        }

        It "Should execute a Bash script" {
            
            $scriptPath = Join-Path $rootPath -ChildPath '..' -AdditionalChildPath  @("Samples", "scripts", "sample-script.sh");

            $command = $scriptPath;

            $arguments = @{
                "FIRST_VAR" = "bash-script-test"
            }

            # Initialize the script prior to execution
            $customScriptExecutor = `
            [CustomScriptExecution]::new(
                $command, 
                $arguments
            );

            # Execute the script by calling Execute method
            $customScriptExecutor.Execute();

            $customScriptExecutor.Result | Should Be "bash-script-test";
        }

        It "Should execute PowerShell Cmdlets" {
            $command = "Write-Output pwsh-test;";

            # Initialize the script prior to execution
            $customScriptExecutor = `
            [CustomScriptExecution]::new(
                $command, 
                @{}
            );

            # Execute the script by calling Execute method
            $customScriptExecutor.Execute();

            $customScriptExecutor.Result | Should Be "pwsh-test";
        }

        It "Should execute Bash Commands" {
            $command = "echo bash-test";

            # Initialize the script prior to execution
            $customScriptExecutor = `
            [CustomScriptExecution]::new(
                $command, 
                @{}
            );

            # Execute the script by calling Execute method
            $customScriptExecutor.Execute();

            $customScriptExecutor.Result | Should Be "bash-test";
        }
    }
}