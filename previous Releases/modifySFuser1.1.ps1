<#
##Name: Jason Saadatmand
##Program Name: modify SalesForce User
##Objective: Automate Process of enabling or disabling any user in any specified SalesForce environmets
##Last Update: March 19, 2015
#>

<#
#Purpose: to extract the arguments from the command line and store them into the return array
#Params: arguments - the string that contains all the command line arguments
#path - the string that contains the pathname for the log where the results are being stored
#Returns:answer    - the 3 dimensional array that contains all the extract names, orgs, and files that are needed to deactivate the users, and whether the users are being activated or deactivated
#>
Function getArgs{
    Param($arguments, $path)
    $inputName=""
    $enable=$false
    foreach ($arg in $arguments) {#runs throught the commandline to extract the flags and information that were set/given
        if ($arg.ToString().StartsWith("/n:")){#extracts the names and put them into the inputName variable as a single string
            $inputName=$arg.ToString().Substring(3,$arg.ToString().length-3)
        }
        if ($arg.ToString().StartsWith("/org:")){#extracts the orgs and put them into the orgList variable as a single string
            $orgList=$arg.ToString().Substring(5,$arg.ToString().length-5)
        }
        if ($arg.ToString() -eq "/enable"){
            $output=[system.String]$(get-date -f yyyy-MM-dd)+" "+[system.String]$(get-date -f HH:mm:ss)+" [getArgs] Params: "+[system.String]$arg
            Write-Host $output
            Add-Content -Path $path -Value $output -Force
            $enable=$true
        }
    }
    if ([string]::IsNullOrWhiteSpace($inputName)) {#if no names were entered    
        [system.String]$output=($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Names specified"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force    
        exit 1  
    }else{#output the names as it got them verbatim
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] Params: /n: "+$inputName
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
        $finalInputName=$inputName.Split(",").Trim()

        <#
        $finalInputName=@()
        foreach($name in $inputName.Split(",").Trim()){
            if ($name.IndexOf(" ") -eq -1){            
                Write-Host ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))" [getArgs]"$name "is not a valid name"
            }else{
                $finalInputName+=$name
                $index++
            }
        }
        #>

        if ([string]::IsNullOrWhiteSpace($finalInputName)){#if none of the entered names passed the cut and were all useless
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] scipt terminated as none of the names entered are valid"
            Write-Host $output
            Add-Content -Path $path -Value $output -Force
            exit 1     
        }
    }

    if ( [string]::IsNullOrWhiteSpace($orgList) ){
        if (Test-Path Sandboxes.txt) {#no orgs were specified and resorted to pulling orgs from file
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Orgs Specified, orgs extracted from Sanboxes.txt file"
            Write-Host $output
            Add-Content -Path $path -Value $output -Force
            $orgNames = (Get-Content Sandboxes.txt)
        }else{#orgs werent specified and file containing orgs not found
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Orgs Specified and Sanbox file not found"
            exit 1
        }
    }else{#orgs were entered in via command line and are saved to the orgNames array
        $orgNames = $orgList.Split(",").Trim()
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] Params: /org: "+$orgList
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
    $answer=@(@(),@(),@())
    $answer[0]=@($finalInputName)
    $answer[1]=@($orgNames)
    $answer[2]=$enable
    #$answer[$global:filesIndex]=@($fileNames.Split(","))

    return $answer
}

<#
#Purpose: calls the functions need to successfully extract users
#Params: configFileName - the name of the config file that the function will be modifying
#names          - the names that will be deactivated
#$orgName       - the org that the users will be deactivated in
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function modifyConfigForExport{
    Param($configFileName, $names, $orgName, $path)
    $success=setNames $configFileName $names $path
    if ($success -eq $false){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyConfigForExport] modification of extractionSOQL for extraction failed as "+$pathName+ " doesn't exist"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
        return $success
    }
    $success=setEnvironment $configFileName $orgName
    if ($success -eq $true){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyConfigForExport] extraction environment set to "+$org
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyConfigForExport] modification of extraction environment failed as "+$pathName+ " doesn't exist"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
    return $success   
}

<#
#Purpose: to set the process-conf to pull the correct users from the orgs
#Params: pathName - the pathname for the config file
#names    - the list of the users will be deactivated
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setNames{
    Param($pathName, $names, $path)
    if ( (Test-Path $pathName) ){#makes sure that the path and the config files exist and are correct
        $testxml =[xml] (Get-Content $pathName)
        foreach ($element in $testxml.beans.bean.property.map.entry) {#changes the org when it comes to exporting the files from the server
            if ($element.key -eq "sfdc.extractionSOQL"){
                foreach ($name in $names) { 
                    if ($names[0] -eq $name){
                        $element.value = $element.value+" WHERE Name like '"+$name+"%'"
                    }else{
                        $element.value = $element.value+" OR Name like '"+$name+"%'"
                    }
                } 
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [setNames] extractionSOQL set to "+ $element.value
                Write-Host $output
                Add-Content -Path $path -Value $output -Force
                $testxml.Save([System.IO.Path]::GetFullPath($pathName))
            }
        }
    }else{
        return $false
    }
    return $true
}

<#
#Purpose: to set the process-conf to pull from the correct org
#Params: pathName - the pathname for the config file
#org - the org to pull from
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setEnvironment{
    Param($pathName, $org, $path)
    if (Test-Path $pathName){
        $testxml=[xml] (Get-Content $pathName)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.username"){
                $element.value = $element.value.Substring(0, $element.value.LastIndexOf('.')+1)+$org
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($pathName))
        return $true
    }
    return $false
}

<#
#Purpose: calls the export file and lets the user know if it was unsuccessful
#Params: org - the org the export file will be trying to pull from
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function extractUsers{
    Param($org, $path)
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] connecting to "+$org+ "......"
    Write-Host $output
    Add-Content -Path $path -Value $output -Force
    .\export\export.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] Unable to connect to org "+$org
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
        return $false
    }
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] connected to "+$org +" and user list extracted"
    Write-Host $output
    Add-Content -Path $path -Value $output -Force
    return $true
}

<#
#Purpose: to disable all the users in the user list
#Params: fileName - the filename for the userlist
#org - the environment that the method is currently modfiying users in
#enable - the flag that determines whether the function is currently enabling or disabling users
#path - the string that contains the pathname for the log where the results are being stored
#names - the names of all the users that the function has to modifying the in specified environment
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function modifyUsers{
    Param($fileName,$org, $enable, $path, $names)
    $answer=@(@(),@())
    if (Test-Path $fileName){#tests to make sure the CSV file exists
        if ( (@(Get-Content $fileName).Length) -gt 1){#tests to see if the file does even have any users before bothering to read it
            ($csv = Import-Csv $fileName -Delimiter ',' ) |
            foreach{
                if ($_.NAME.IndexOf("(") -ne -1) { #Normalize the target name (get rid of any bracketed info)
                    $parsedName = $_.NAME.Substring(0,$_.NAME.IndexOf("(")).trim()
                } else {
                    $parsedName = $_.NAME.trim()
                }
                $parsedUserName = $_.USERNAME.Substring(0,$_.USERNAME.IndexOf("@")).trim()
                foreach($name in $names){#runs through the names the user specified
                    if ($name -match $parsedName){#to make sure the name on the list is an exact match before attempting to modify it
                        if ( !( $parsedUserName -match '^sfdcadmin[0-9][^0-9]' -or $parsedUserName -match '^sfdcadmin[0-9]$'  -or $parsedUserName -match '^csf-*'  ) ){#and it makes sure that the user isn't an admin
                            if ($enable -eq $false){#tests to see if the user had wanted to disable or enable the specified accounts
                                if ($_.ISACTIVE -eq "TRUE"){
                                    $_.ISACTIVE = "FALSE"
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [disableAllUsers] Disabled: " +$_.USERNAME +"`n"
                                    $csv | select ID, ISACTIVE | Export-Csv $fileName -Delimiter ',' -NoType
                                }else{
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [disableAllUsers] Already disabled: " +$_.USERNAME +"`n"
                                }
                            }else{
                                if ($_.ISACTIVE -eq "FALSE"){
                                    $_.ISACTIVE = "TRUE"
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [disableAllUsers] Enabled: " +$_.USERNAME +"`n"
                                    $csv | select ID, ISACTIVE | Export-Csv $fileName -Delimiter ',' -NoType
                                }else{
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [disableAllUsers] Already enabled: " +$_.USERNAME +"`n"
                                }
                            }
                        }
                    }
                }
            }
        }else{#if no user were pulled from the environment as none matched the names specified
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [disableAllUsers] no users with the specified names exist in "+$org
            Write-Host $output
            Add-Content -Path $path -Value $output -Force
            $answer[0]=$false
            return $answer
        }
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [disableAllUsers] modifying specified users failed for " +$org +" as "+ $fileName +" doesn't exist"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
        $answer[0]=$false
        return $answer
    }
    $answer[0]=$true
    return $answer
}

<#
#Purpose: to move the files from the export folder to the update folder for update
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function moveFiles{
    if (Test-Path update\read\update.csv){#tests to see if the CSV file exists
        rm update\read\update.csv -ErrorAction SilentlyContinue
    }
    mv .\export\write\export.csv .\update\read\update.csv
    return $true
}

<#
#Purpose: calls the export file and lets the user know if it was unsuccessful
#Params: org - the org the export file will be trying to pull from
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function updateUsers{
    Param($org, $path)
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] user list being uploaded for " +$org
    Write-Host $output
    Add-Content -Path $path -Value $output -Force
    [system.String]$output=     .\update\update.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] Was not able to upload the user list to "+$org
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
        return $false
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] user list uploaded for "+$org
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
    return $true
}

<#
#Purpose: to get the extractionSOQL back to what it original was in perparation for the next time the script is run
#Params: pathName - the name of the path for the xml file that contains the extractionSOQL
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function restoreConfigFiles{
    Param($pathName, $path)
    if (Test-Path $pathName){
        $testxml=[xml] (Get-Content $pathName)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.extractionSOQL"){
                $element.value = $element.value.Substring(0, 45)
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [restoreConfigFiles] extractionSOQL reset to "+ $element.value
                Write-Host $output
                Add-Content -Path $path -Value $output -Force
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($pathName))
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [restoreConfigFiles] reset of extractionSOQL failed as "+$pathName+ " doesn't exist"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
}

<#
#Purpose: to set the extractionSOQL back to what it original was if the last time the script was run, the user terminated the script with Ctrl+c instead of waiting for the script to finish its run
#Params: pathName - the name of the path for the xml file that contains the extractionSOQL
#path - the string that contains the pathname for the log where the results are being stored
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setupExportFile{
    Param($pathName, $path)
    if (Test-Path $pathName){
        $testxml=[xml] (Get-Content $pathName)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.extractionSOQL"){
                $element.value = "SELECT Id, Name, isActive, username FROM User"
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [setupExportFile] extractionSOQL set to "+ $element.value
                Write-Host $output
                Add-Content -Path $path -Value $output -Force
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($pathName))
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [setupExportFile] setting extractionSOQL failed as "+$pathName+ " doesn't exist"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
}

[System.String]$path=[System.String]$PWD+"`\logs`\"+[System.String]$(get-date -f yyyy-MM-dd)+"-"+[System.String]$(get-date -f HH-mm-ss)+".log"
$results = getArgs $args $path
setupExportFile $PWD"\export\config\process-conf.xml" $path

foreach ($org in $results[1]){
    $success=modifyConfigForExport $PWD"\export\config\process-conf.xml" $results[0] $org $path
    if ($success -eq $true){
        $success=extractUsers $org $path
    }
    if ($success -eq $true){
        $success=modifyUsers $PWD\export\write\export.csv $org $results[2] $path $results[0]
        $result=$success[1]
    }
    if ($success -eq $true){
        $success=moveFiles
    }
    if ($success -eq $true){
        $success=setEnvironment $PWD"\UPDATE\config\process-conf.xml" $org $path
    }
    if($success -eq $true){
        $success = updateUsers $org $path
    }
    if ($success -eq $true){
        Write-Host $result
        Add-Content -Path $path -Value $result -Force
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [disableSFuser] "+$org+" wasnt updated successfully"
        Write-Host $output
        Add-Content -Path $path -Value $output -Force
    }
    restoreConfigFiles $PWD"\export\config\process-conf.xml" $path
}