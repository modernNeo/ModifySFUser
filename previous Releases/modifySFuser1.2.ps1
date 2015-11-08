<#
##Name: Jason Saadatmand
##Program Name: modify SalesForce User
##Objective: Automate Process of enabling or disabling any user in any specified SalesForce environmets
##Last Update: March 26, 2015
#>

[system.string]$Global:extractionConfPath=[system.string]$PWD+"\export\config\process-conf.xml"
[system.string]$Global:logPath=[System.String]$PWD+"`\logs`\"+[System.String]$(get-date -f yyyy-MM-dd)+"-"+[System.String]$(get-date -f HH-mm-ss)+".log"
[system.string]$Global:alreadyRunningPath= [system.string]$PWD+"\alreadyRunning"
[system.string]$Global:exportCSVPath=[system.string]$PWD+"\export\write\export.csv"
[System.String]$Global:updateCSVPath=[System.String]$PWD+"\update\read\update.csv"
[system.string]$Global:updateConfPath=[system.string]$PWD+"\update\config\process-conf.xml"
[system.string]$Global:nameOfEnvFile="Sandboxes-condensed.txt"
<#
#Purpose: to extract the arguments from the command line and store them into the return array
#Params:
#arguments      - the string that contains all the command line arguments
#Returns:answer - the 3 dimensional array that contains all the extract names, orgs, and files that are needed to deactivate the users, and whether the users are being activated or deactivated
#>
Function getArgs{
    Param($arguments)
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
            Add-Content -Path $logPath -Value $output -Force
            $enable=$true
        }
    }
    
    #testing the names to make sure that there were actual entries
    if ([string]::IsNullOrWhiteSpace($inputName)) {#if no names were entered    
        [system.String]$output=($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Names specified"
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force    
        exit 1  
    }else{#output the names as it got them verbatim
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] Params: /n: "+$inputName
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
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
        

        if ([string]::IsNullOrWhiteSpace($finalInputName)){#if none of the entered names passed the cut and were all useless
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] scipt terminated as none of the names entered are valid"
            Write-Host $output
            Add-Content -Path $path -Value $output -Force
            exit 1     
        }#>
    }

    #testing the orgs specified to make sure that either there were entries or the backup textfile is accessible
    if ( [string]::IsNullOrWhiteSpace($orgList) ){
        if (Test-Path $nameOfEnvFile) {#no orgs were specified and resorted to pulling orgs from file
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Orgs Specified, orgs extracted from Sanboxes.txt file"
            Write-Host $output
            Add-Content -Path $logPath -Value $output -Force
            $orgNames = (Get-Content $nameOfEnvFile)
        }else{#orgs werent specified and file containing orgs not found
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] No Orgs Specified and Sanbox file not found"
            Write-Host $output
            Add-Content -Path $logPath -Value $output -Force
            exit 1
        }
    }else{#orgs were entered in via command line and are saved to the orgNames array
        $orgNames = $orgList.Split(",").Trim()
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [getArgs] Params: /org: "+$orgList
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
    }
    $answer=@(@(),@(),@())
    $answer[0]=@($finalInputName)
    $answer[1]=@($orgNames)
    $answer[2]=$enable
    #$answer[$global:filesIndex]=@($fileNames.Split(","))

    return $answer
}

<#
#Purpose: to set the process-conf to pull from the correct org
#Params: 
#pathName     - the pathname for the config file
#env          - the org to pull from
#Return: bool -indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setEnvironment{
    Param($pathName, $env)
    if (Test-Path $pathName){
            $testxml=[xml] (Get-Content $pathName)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.username"){
                $element.value = $element.value.Substring(0, $element.value.LastIndexOf('.')+1)+$env
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($pathName))
        return $true
    }
    return $false
}

<#
#Purpose: calls the export file and lets the user know if it was unsuccessful
#Params: 
#env          - the org the export file will be trying to pull from
#Return: 2d array -first index indicates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#                  second index has the output of whether or not the script was able to connect to the org for the email notication that will be sent out
#>
Function callExportEXE{
    Param($env)
    $result=@(@(),@())
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] connecting to "+$env+ "......"
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
    $garbage=.\export\export.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] Unable to connect to org "+$env
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        $result[1]=$output;
        $result[0]=$false
        return $result
    }
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [extractUsers] connected to "+$env +" and user list extracted"
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
    $result[1]=$output;
    $result[0]=$true
    return $result
}

<#
#Purpose: to disable all the users in the user list
#Params: 
#fileName         - the filename for the user list
#env              - the environment that the method is currently modfiying users in
#enable           - the flag that determines whether the function is currently enabling or disabling users
#names            - the names of all the users that the function has to modifying the in specified environment
#Return: 3d array - first index indcates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#                 - second index has the output of the user that were modified
#                 - third index has the output of the user that weren't modified
#                 - fourth index indicates whether or not any users were actually modified
#>
Function modifyUsers{
    Param($env, $enable, $names)
    $answer=@(@(),@(),@(),@())
    $answer[3]=$false
    $noModifiedOutput=$true
    $noUnmodifiedOutput=$true
    if (Test-Path $Global:exportCSVPath){#tests to make sure the CSV file exists
        if ( (@(Get-Content $Global:exportCSVPath).Length) -gt 1){#tests to see if the file does even have any users before bothering to read it
            ($csv = Import-Csv $Global:exportCSVPath -Delimiter ',' )|
            foreach{
                if ($_.NAME.IndexOf("(") -ne -1) { #Normalize the target name (get rid of any bracketed info)
                    $parsedName = $_.NAME.Substring(0,$_.NAME.IndexOf("(")).trim()
                } else {
                    $parsedName = $_.NAME.trim()
                }
                $parsedUserName = $_.USERNAME.Substring(0,$_.USERNAME.IndexOf("@")).trim()
                foreach($name in $names){#runs through the names the user specified
                    if ($name -match $parsedName){#to make sure the name on the list is an exact match before attempting to modify it
                        if ( !( $parsedUserName -match '^sfdcadmin[0-9]$'  -or #sfdcadmin5@rbauction.com.test01f should not be disabled
                        $parsedUserName -match '^csf-*'  ) ){#and it makes sure that the user doesnt start with csf-                           
                            if ($enable -eq $false){#tests to see if the user had wanted to disable or enable the specified accounts
                                if ($_.ISACTIVE -eq "TRUE"){
                                    $_.ISACTIVE = "FALSE"
                                    $answer[3]=$true
                                    if ($noModifiedOutput -eq -$false){
                                        $answer[1]+="`n"
                                    }
                                    $noModifiedOutput=$false
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Disabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{
                                    if ($noUnmodifiedOutput -eq -$false){
                                        $answer[2]+="`n"
                                    }  
                                    $noUnmodifiedOutput = $false
                                    [string]$answer[2]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already disabled: " +$_.USERNAME
                                }
                            }else{
                                if ($_.ISACTIVE -eq "FALSE"){
                                    $_.ISACTIVE = "TRUE"
                                    $answer[3]=$true
                                    if ($noModifiedOutput -eq -$false){
                                        $answer[1]+="`n"
                                    }
                                    $noModifiedOutput=$false
                                    [string]$answer[1]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Enabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{
                                    if ($noUnmodifiedOutput -eq -$false){
                                        $answer[2]+="`n"
                                    }
                                    $noUnmodifiedOutput = $false
                                    [string]$answer[2]+= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already enabled: " +$_.USERNAME
                                }
                            }
                            
                        }
                   }
                }
            }
        }else{#if no user were pulled from the environment as none matched the names specified
            [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyUsers] CSV empty as none of the downloaded users were a match for the specified name in  "+$env
            Write-Host $output
            Add-Content -Path $logPath -Value $output -Force
            $answer[0]=$false
            return $answer
        }
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyUsers] modifying specified users failed for " +$env +" as "+ $Global:exportCSVPath +" doesn't exist"
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        $answer[0]=$false
        return $answer
    }
    $answer[0]=$true
    return $answer
}

<#
#Purpose: calls the export file and lets the user know if it was unsuccessful
#Params: 
#env              - the org the export file will be trying to pull from
#Return: 2d array -first index indicates if the function was able to connect to the env specified
#                  second index has the output of whether or not the script was able to connect to the env for the email notication that will be sent out
#>
Function callUpdateEXE{
    Param($env)
    $result=@(@(),@())
    [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] users being updated in " +$env+"....."
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
    $garbage=.\update\update.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] connection error, couldn't update users in "+$env
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        $result[0]=$false
        $result[1]=$output
        return $result
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [updateUsers] update complete in "+$env
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        return $true
    }
}

<#
#Purpose: to set the extractionSOQL to what it original was to prepare for the upcoming modification in setNames function
#Params:
#names        - the array with all the names that the script has been asked to modify 
#Return: bool - indicates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setExtractionSOQL{
    Param( $names)
    if (Test-Path $Global:extractionConfPath){
        $testxml=[xml] (Get-Content $Global:extractionConfPath)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.extractionSOQL"){
                $element.value = "SELECT Id, Name, isActive, username FROM User"
                foreach ($name in $names) { 
                    if ($names[0] -eq $name){
                        $element.value = $element.value+" WHERE Name like '"+$name+"%'"
                    }else{
                        $element.value = $element.value+" OR Name like '"+$name+"%'"
                    }
                } 
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [setupExportFile] extractionSOQL set to "+ $element.value
                Write-Host $output
                Add-Content -Path $logPath -Value $output -Force
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($Global:extractionConfPath))
        return $true
    }else{
        [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [setupExportFile] setting extractionSOQL failed as "+$Global:extractionConfPath+ " doesn't exist"
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        return $false
    }
}

#try catch format makes sure that the script will send out the email and remove the alreadyRunning file even if script is killed with Ctrl+c
try{
    $alreadyRunning=$false

    if (Test-Path $Global:alreadyRunningPath){#checks to see if the process is already running
        $output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifySFUser] Process is already running"
        Write-Host $output
        Add-Content -Path $logPath -Value $output -Force
        $alreadyRunning=$true
        exit 1
    }else{
        Add-Content -Path $Global:alreadyRunningPath -Value "live long and prosper" -Force
    }

    if ($args.count -eq 0 -or  $args -match "\?" -or $args -match "/help"){#checks to see if the script was called with no arguements, /? or /help
        clear
        Get-Content HELP_ME.txt
        cat HELP_ME.txt  > $logPath
        exit 1
    }

   
    $results = getArgs $args
    $emailUserList=""
    $emailEnvList=""
    $success=setExtractionSOQL $results[0]
    if ($success -eq $true){
        foreach ($env in $results[1]){
            rm $Global:updateCSVPath -ErrorAction SilentlyContinue
            rm $Global:exportCSVPath -ErrorAction SilentlyContinue

            $success=setEnvironment $Global:extractionConfPath $env
            if ($success -eq $true){#extraction environment set to env
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifySFUser] extraction username pointing to "+$env
                Write-Host $output
                Add-Content -Path $logPath -Value $output -Force
                $success=callExportEXE $env
            }else{#not able to set extraction environment to env
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyConfigForExport] modification of extraction environment failed as ("+$Global:extractionConfPath+ ") doesn't exist"
                Write-Host $output #screen
                Add-Content -Path $logPath -Value $output -Force #log
                $emailEnvResults+="`n"+$output #email
                exit 1
            }


            #$success=callExportEXE $org $logPath
            if ($success[0] -eq $true){#CSV user list successfully downloaded
                $success=modifyUsers $env $results[2] $results[0]
                $userModifiedResults=$success[1]
                $userNotModifiedResults=$success[2]
            }else{#could not connect to the environment to download CSV user list
                $emailEnvList+="`n"+$success[1]
                continue
            }


            #$success=modifyUsers $PWD\export\write\export.csv $org $results[2] $logPath $results[0]
            if ($success[0] -eq $false){#if csv was empty or does not exist
                continue
            }elseif ($success[3] -eq $false){# if none of the downloaded users were modifiedE
                if (![string]::IsNullOrEmpty($userNotModifiedResults)){#prints out the list of users that were not modified
                    Write-Host $userNotModifiedResults
                    Add-Content -Path $logPath -Value $userNotModifiedResults -Force #prints out the results for all the users to the logs
                    continue
                }

                #if it didnt manage to match any of the downloaded users to any specified users
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifySFUser] no users in "+$env+" were updated"
                Write-Host $output
                Add-Content -Path $logPath -Value $output -Force
                continue
             }


            $success=setEnvironment $Global:updateConfPath $env
            if ($success -eq $true){#update environment set to env
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifySFUser] username for upload pointing to "+$env
                Write-Host $output
                Add-Content -Path $logPath -Value $output -Force
                $success = callUpdateEXE $env
            }else{#not able to set update environment to env
                [system.String]$output= ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+" [modifyConfigForExport] modification of updating environment failed as ("+$Global:updateConfPath + ") doesn't exist"
                Write-Host $output
                Add-Content -Path $logPath -Value $output -Force
                exit 1
            }

            #$success = callUpdateEXE $org $logPath
            if ($success[0] -eq $true){#CSV user list successfully uploaded
                if (![string]::IsNullOrEmpty($userModifiedResults)){#adds the list of users that were modified to the email variable as well as prints them out to the screen
                    Write-Host $userModifiedResults 
                    $emailUserList+="`n"+$userModifiedResults
                }
                if (![string]::IsNullOrEmpty($userNotModifiedResults)){#prints out the list of users that were not modified
                    Write-Host $userNotModifiedResults
                }
                Add-Content -Path $logPath -Value $userModifiedResults$userNotModifiedResults -Force #prints out the results for all the users to the logs
            }else{#could not connect to the environment to download CSV user list
                $emailEnvList+="`n"+$success[1]
            }
        }
    }
}finally{
    $From = "jsaadatmand@rbauction.com"
    $To = "jsaadatmand@rbauction.com"
    $Subject = "Account Modification in Salesforce"
    
    $Body=""

    if ( [string]::IsNullOrEmpty($emailUserList)){
        if ([string]::IsNullOrEmpty($emailEnvList)){
            $Body+= "This email was autogenerated from modifySFUser" 
        }else{
            $Body+=$emailEnvList;
        }
    }else{
        $Body+= $emailUserList
        if (![string]::IsNullOrEmpty($emailEnvList)){
            $Body+="`n"+$emailEnvList;
        }
    }

    $SMTPServer = "rbsinf1.qasalesite.rbauction.net"
    $SMTPPort = "25"
    if (Test-Path $logPath){
       Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments "$logPath"
    }else{
       Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort
    }

    if ($alreadyRunning -eq $false){
        rm alreadyRunning
    }
}