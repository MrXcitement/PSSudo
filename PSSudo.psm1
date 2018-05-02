function Start-Elevated {

    if($args.Length -eq 0) {
        $program = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $cmdLine = "-ExecutionPolicy $(Get-ExecutionPolicy) -NoLogo"
    }
    else {
        if($args.Length -ne 1) {
            $cmdLine = [string]::Join(' ', ($args[1..$args.Length] | % { '"' + (([string] $_).Replace('"', '""')) + '"' }) )
        }
        else {
            $cmdLine = ''
        }

        $cmd = $args[0]

        if($cmd -is [ScriptBlock]) {
            $tempFile = [System.IO.FileInfo] [System.IO.Path]::GetTempFileName();
            $scriptFile = Join-Path $tempFile.Directory ($tempFile.BaseName + '.ps1');

            Set-Content $tempFile ([string] $cmd);
             
            mv $tempFile $scriptFile;

            $cmd = $scriptFile;

            $cmdLine = "$cmdLine; rm $scriptFile";

        }

        else {

            $alias = Get-Alias $cmd -ErrorAction SilentlyContinue;
            while($alias) {
                $cmd = $alias.Definition;
                $alias = Get-Alias $cmd -ErrorAction SilentlyContinue;
            }
        }

        $cmd = Get-Command $cmd -ErrorAction SilentlyContinue

        switch -regex ($cmd.CommandType) {
            'Application' {
                $program = $cmd.Source
            }
            'Cmdlet|Function' {
                $program = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

                $cmdLine = "$($cmd.Name) $cmdLine"
                $cmdLine = "-NoLogo -Command `"$cmdLine; pause`""

            }
            'ExternalScript' {
                $program = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

                $cmdLine = "& '$($cmd.Source)' $cmdLine"
                $cmdLine = "-NoLogo -Command `"$cmdLine; pause`""
            }
            default {
                Write-Warning "Command '$($args[0])' not found."
                return
            }
        }
    }

    $psi = new-object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $program

    $emuHk = $env:ConEmuHooks -eq 'Enabled'
    if($emuHk) {
        $psi.UseShellExecute = $false
        $psi.Arguments = "-new_console:a $cmdLine";
        $psi.WorkingDirectory = $(Get-Location)
    }
    else {
        $psi.Verb = "runas"
        $psi.Arguments = $cmdLine
    }

    [System.Diagnostics.Process]::Start($psi) | out-null

}

Set-Alias sudo Start-Elevated

