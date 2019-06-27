Class CustomScriptExecution {

    hidden $scriptType = "";
    hidden $command = "";
    hidden $arguments = @{};
    
    # Used to store results from the script execution
    $Result = "";
    
    CustomScriptExecution([string] $command, [hashtable] $arguments) {
        # Derive the script type from the command being
        # passed
        $this.scriptType = `
            $this.GetScriptType($command);
        $this.command = $command;
        $this.arguments += $arguments;
    }

    [void] Execute() {

        # Branch the execution based on the type of the script being
        # passed for execution.
        switch ($this.scriptType.ToLower()) {
            "powershellscript" {
                $this.Result = $this.RunPowerShellScript("script");
            }
            "powershellcommands" {
                $this.Result = $this.RunPowerShellScript("command");
            }
            "bash" {
                $this.Result = $this.RunBashScript();
            }
        }
    }

    hidden [array] GetScriptType([string] $command) {
        $powershellScriptPattern = "^(.*?)\.ps1";
        $bashScriptPattern = "^(.*?)\.sh";

        # Check if the command contains ".ps1" extension
        # files.
        if($command -match $powershellScriptPattern) {
            return "powershellscript";
        }
        # Check if the command contains ".sh" extension
        # files.
        elseif($command -match $bashScriptPattern) {
            return "bash";
        }
        # Check if the command contains PowerShell Cmdlets
        elseif($this.IsPowerShellCmdletPresentInCommand($command)) {
            return "powershellcommands";
        }
        # If none of the above conditions are met, assume
        # the type is a set of bash commands
        else {
            return "bash";
        }
    }

    hidden [bool] IsPowerShellCmdletPresentInCommand([string] $command) {

        # Get the first work from the command string to 
        # determine if it's a PowerShell Script, because 
        # PowerShell scripts always start with a known Cmdlet.
        # For Example: Get-Content, ConvertFrom-Json and so on.
        $cmdlet = ($command -split ' ')[0];

        # Use Get-Command to check if the retrieved word is a 
        # valid PowerShell Cmdlet.
        $cmdlet = `
            Get-Command `
                -Name $cmdlet `
                -ErrorAction SilentlyContinue;
                
        if($null -ne $cmdlet `
            -and $cmdlet.CommandType -eq "Cmdlet") {
            return $true;
        }
        else {
            return $false;
        }

    }

    hidden [array] AddArgumentsForExecution([string] $type) {

        # Get arguments for the script execution
        if($type -eq "powershellscript") {
            return `
                $this.GetArgumentsForPowerShellScript();
        }
        elseif($type -eq "bash") {
            return `
                $this.GetArgumentsForBashScript();
        }
        else {
            # Return null if the type is not PowerShell script
            # or bash script
            return $null;
        }
    }

    hidden [array] GetArgumentsForBashScript() {

        # Variable to hold the list of arguments to be
        # passed to the bash script execution
        $orderedArguments = @();

        # Add the arguments to the array as-is as 
        # there is no way to verify the order in bash.
        # We are only converting the hashtable to an 
        # array
        $this.arguments.Keys | ForEach-Object {
            $argumentName = $_;
            $orderedArguments += $this.arguments[$argumentName];
        }

        # Return the arguments list
        return $orderedArguments;
    }

    hidden [array] GetArgumentsForPowerShellScript() {

        # List of system parameters we can pass to a 
        # PowerShell script by default
        $systemParameters = `
            @(
                'Verbose',
                'Debug',
                'ErrorAction',
                'WarningAction',
                'InformationAction',
                'ErrorVariable',
                'WarningVariable',
                'InformationVariable',
                'OutVariable',
                'OutBuffer',
                'PipelineVariable'
            );

        # Variable to hold the ordered list of arguments to 
        # be passed to the script execution
        $orderedArguments = @();

        # Iterate through the list of Parameters accepted by
        # a script to rearrange the in argument in the right order.
        (Get-Command $this.command).Parameters.Keys | ForEach-Object {
            $parameterName = $_;

            # Add the argument to a new array in the right order if
            # it is passed from the orchestation. Otherwise, add a 
            # null in its place
            if($this.arguments.ContainsKey($parameterName) `
                -and $parameterName -notin $systemParameters) {
                $orderedArguments += $this.arguments[$parameterName];
            }
            elseif($parameterName -notin $systemParameters) {
                $orderedArguments += $null;
            }
        }

        # Return the ordered arguments list
        return $orderedArguments;
    }

    hidden [string] RunPowerShellScript([string] $type) {

        # Branch based on the type of PowerShell to
        # run (i.e script or set of commands)
        if($type -eq "script") {

            # Get arguments to execute the PowerShell script
            $argumentsList = `
                $this.AddArgumentsForExecution($this.scriptType);

            # Pass the script file path and argumentsList to
            # execute the script
            return `
                $this.RunJob($null, $this.command, $argumentsList);
        }
        else {

            # Pass the PowerShell commands to execute
            return `
                $this.RunJob($this.command, $null, $null);
        }
    }

    hidden [string] RunBashScript() {

        # Get arguments to execute the bash script
        $argumentsList = `
            $this.AddArgumentsForExecution($this.scriptType);

        # Append the arguments to the end of the bash script
        $this.command = `
            ("bash -c '{0} {1}'" -F $this.command, [string]$argumentsList);
        
        # Return the formatted command
        return `
            $this.RunJob($this.command, $null, $null);
    }

    hidden [string] RunJob([string] $command, [string] $filePath, [array] $argumentsList) {
        
        # Variable to store the output from running a script
        $resultant = "";

        try {
            $job = $null;

            # Job is a set of commands to be executed
            if(![string]::IsNullOrEmpty($command)) {

                $job = Start-Job -ScriptBlock {
                    param($command)
                    $script = [scriptblock]::Create($command);
                    . $script;
                } -ArgumentList $command
            }
            # Job is a script file to be executed
            elseif(![string]::IsNullOrEmpty($filePath)) {
                $job = `
                    Start-Job `
                        -FilePath $filePath `
                        -ArgumentList $argumentsList;
            }

            # Did the job start successfully?
            if ($null -ne $job) {

                # Wait for the job to complete
                While($job.JobStateInfo.State -ne "Completed" ) {
                    $job = Get-Job -Name $job.Name;
                    Write-Debug "Waiting for Script to finish ... ";
                    Start-Sleep -s 6;
                }
                
                # Child job contains the output from running the commands
                # or script file. It is always only one child job in our 
                # case since we start only one job.
                (Get-Job -Name $job.Name).ChildJobs | ForEach-Object {
                    $resultant = $_.Output[$_.Output.Count-1].ToString();
                };
            }
        }
        catch {
            Write-Error "An exception occurred when running the script."
            Write-Error $_;
        }

        # Return the latest output
        return $resultant;
    }

}