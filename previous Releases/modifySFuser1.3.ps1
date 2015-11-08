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
[system.string]$Global:nameOfEnvFile="SandboxesCC.txt"
[system.string]$Global:nameOfuserList="users.csv"
[system.string]$Global:outfile= "userList.txt"

<#
#Purpose: to add a stamp to the given string  and write it to the command line and to the log
#Params: 
#output   the string that has to be outputted
#>
Function writeOutput{
    Param($output)
    $output = ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ $output
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
}
<#
#Purpose: to write the given string to the command line and to the log
#Params: 
#output   the string that has to be outputted
#>
Function writeOutputWithStamp{
    Param($output)
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
}
<#
#Purpose: to test to see if the given string is valid (has actual characters) or is invalid (is empty or null or just has blank spaces
#Params: 
#theString   the string that will be tested
#Return:     true if the string is valid and false if it is not
#>
Function isValidString{
    Param($theString)
    
    if ($theString -is [system.array] -and $theString.Count -gt 0){
        $notValid=$true;
        for($i = 0 ; $i -lt $theString.Count ; $i++){
            if ([string]::IsNullOrEmpty($theString[$i]) -or [string]::IsNullOrWhiteSpace($theString[$i])){
                $notValid=$false
            }
        }
        return $notValid
    }
    return !([string]::IsNullOrEmpty($theString) -or [string]::IsNullOrWhiteSpace($theString))
}
<#
#Purpose: to write the given string to the command line and to the log
#Params: 
#arguments   the command line arguments that the function will be parsing through
#names       the array that will contains any name(s) pulled from the command line
#activeFlag  the variable that will indicate if the users are being enabled or disabled
#emails      the array that will contain any email address(es) pulled from the command line
#org         the array that will contain any org(s) pulled from the command line
#>
Function getArgs{
    Param($arguments, [ref]$names,[ref]$activeFlag, [ref]$emails, [ref]$org)
    $inputName=""
    $name=$false
    $env=$false
    $emailFlag=$false
    $fileParameterFlag=$false
    $fileParameterSet=$false
    $disableFlag=$false
    foreach ($arg in $arguments) {#runs throught the commandline to extract the flags and information that were set/given
        if ($name -eq $true){#extrcts the name(s)
            $inputName=$arg.ToString()
            $name=$false
            continue
        }
        if ($env -eq $true){#extracts the environment(s)
            $orgList=$arg.ToString()
            $env=$false
            continue
        }
        if ($emailFlag -eq $true){#extracts the email recipient provided
            $inputEmail=$arg.ToString()
            $emailFlag=$false
            continue
        }
        if ($fileParameterFlag -eq $true){#read the files in the folder specified by the f parameter
            $fileParameterFlag=$false
            $fileParameterSet=$true
#            exit 1
            cd $arg.ToString()
#            cd ../
#            exit 1
            $files= Get-ChildItem
            for ($i=0; $i -lt $files.Count; $i++) {
                if ($files[$i] -match '.txt$'){
                    Get-Content $files[$i].FullName |  Out-File -Append ../$outfile
                }
                mv $files[$i].FullName ..\Done\$files[$i].FullName
                exit 1
            }
            cd ../../

            Write-Host "pwd: "
            pwd
            Write-Host "end"
            continue
        }
        if ($arg.ToString() -eq "-n:"){#makes the foreach loop go to the next iteration to extract the name
            if (isValidString $inputName ){
                writeOutput " [getArgs] error: -n parameter used twice"
                exit 1
            } 
            $name=$true
            continue
        }
        if ($arg.ToString() -eq "-org:"){#makes the foreach loop go to the next iteration to extract the org
            if (isValidString $orgList ){
                writeOutput " [getArgs] error: -org parameter used twice"
                exit 1
            } 
            $env=$true
            continue
        }
        if ($arg.ToString() -eq "-enable"){#sets the enable flag
            if ($disableFlag -eq $true){
                writeOutput " [getArgs] error: both -enable and -disable parameters used"
                exit 1
            }
            $activeFlag.Value=$true
        }
        if ($arg.ToString() -eq "-disable"){
            if ($activeFlag.Value -eq $true){
                writeOutput " [getArgs] error: both -enable and -disable parameters used"
                exit 1
            }
            $disableFlag=$true
        }
        if ($arg.ToString() -eq "-email:" -or $arg.ToString() -eq "-to:"){#makes the foreach loop go to the next iteration to extract the email recipient
            if (isValidString $inputEmail ){
                writeOutput " [getArgs] error: email paramters -email and -to used twice"
                exit 1
            } 
            $emailFlag=$true
            continue
        }
        if ($arg.ToString() -eq "-f:"){#makes the foreach loop go to the next iteration to extract the arguments in the folder specified by the f parameter
            if ( $fileParameterSet -eq $true ){
                writeOutput " [getArgs] error: -f parameter used twice"
                exit 1
            } 
            $fileParameterFlag=$true
            continue
        }
    }
    exit 1
    if ($fileParameterSet -eq $true){#if the script was instructed to read the names and enable parameter from a folder contents
        if (Test-Path $nameOfEnvFile) {#pulling orgs from file
            writeOutput " [getArgs] orgs extracted from " +$Global:nameOfEnvFile+ " file for -f parameter"
            $orgNames = (Get-Content $nameOfEnvFile)
            $org.Value= @($orgNames) | foreach{$_}
            return
        }else{#file containing orgs not found
            writeOutput " [getArgs] "+$Global:nameOfEnvFile+ " file not found for -f parameter"
            exit 1
        }
    }
    if (isValidString($inputEmail)){#if an email recipient was specified
        if( $inputEmail.IndexOf(",") -eq -1 -and $inputEmail.IndexOf(";") -eq -1){#if only one email was entered
            $emailList = $inputEmail.Split(",").Trim()
        }else{
            $emailList = $inputEmail.Split(";,").Trim()
        }
        $emails.Value =$emailList
        writeOutput ( " [getArgs] Params: -email:" + $emails.Value )
    }
    #outputs which IsActive flag was set
    if ($activeFlag.Value -eq $false){
        writeOutput " [getArgs] Params: -disable"
    }else{
        writeOutput " [getArgs] Params: -enable"
    }

    #TESTING THE NAMES ENTERED
    #testing the names to make sure that there were actual entries
    if ([string]::IsNullOrWhiteSpace($inputName)) {#if no names were entered    
        writeOutput " [getArgs] No Names specified"
        exit 1  
    }

    writeOutput (" [getArgs] Params: -n: "+$inputName)
    foreach ($_ in $inputName.Split(",;").Trim()){
        $names.Value+=$_
    }




    #testing the orgs specified to make sure that either there were entries or the backup textfile is accessible
    if ( ![string]::IsNullOrWhiteSpace($orgList) ){
        writeOutput ( " [getArgs] Params: -org: "+$orgList )
        $org.Value= @($orgList.Split(",;").Trim()) | foreach{$_}
    }else{

        if (Test-Path $nameOfEnvFile) {#no orgs were specified and resorted to pulling orgs from file
            writeOutput " [getArgs] No Orgs Specified, orgs extracted from "+$Global:nameOfEnvFile+ " file"
            $org.Value = (Get-Content $nameOfEnvFile)
        }else{#orgs werent specified and file containing orgs not found
            writeOutput " [getArgs] No Orgs Specified and "+$Global:nameOfEnvFile+ " file not found"
            exit 1
        }
    }


}

<#
#Purpose: to set the process-conf to pull from the correct org
#Params: 
#pathName     - the pathname for the config file
#env          - the org to pull from
#Return: bool -indicates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
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
#Return       -true if the function executed properly to let the main know its safe to keep going or false if the script has to be terminated early due to a bug
#>
Function callExportEXE{
    Param($env, [ref]$connectionResult)
    writeOutput ( " [extractUsers] connecting to "+$env+ "......" )
    $garbage=.\export\export.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output=" [extractUsers] Unable to connect to org "+$env
        writeOutput $output
        $connectionResult.Value = ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+$output
        return $false
    }
    [system.String]$output= " [extractUsers] connected to "+$env +" and user list extracted"
    writeOutput $output
    $connectionResult.Value = ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+$output
    return $true
}

<#
#Purpose: to enable or disable all the users in the user list
#Params: 
#env              - the environment that the method is currently modfiying users in
#enable           - the flag that determines whether the function is currently enabling or disabling users
#names            - the names of all the users that the function has to modifying the in specified environment
#userModifiedList - the string containing the results of all the modified user
#userNotModifiedList - the string containing the results of all the users that weren't modified
#Return: 2d array - first index indicates whether the CSV wasn't found or was empty
#                 - second index indicates whether or not any users were actually modified
#>
Function modifyUsers{
    Param($env, $enable, $names, [ref]$userList)
    $answer=@(@(),@())
    $answer[1]=$false
    $noModifiedOutput=$true
    $noUnmodifiedOutput=$true
    $userExists=$false
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
                foreach($name in $names){#runs through the names the user specified\

                    if ($name -match $parsedName){#to make sure the name on the list is an exact match before attempting to modify it
                        $userExists=$true
                        if ( !( $parsedUserName -match '^sfdcadmin[0-9]$'  -or #sfdcadmin5@rbauction.com.test01f should not be disabled
                        $parsedUserName -match '^csf-*'  ) ){#and it makes sure that the user doesnt start with csf-        
                
                            if ($enable -eq $false){#tests to see if the user had wanted to disable or enable the specified accounts
                
                                if ($_.ISACTIVE -eq "TRUE"){
                                    $_.ISACTIVE = "FALSE"
                                    $answer[1]=$true#sets a flag to indicate that at least one user has been modified
                                    
                                    #set in place for formatting output
                                    if ($noModifiedOutput -eq $false){
                                        $userList.Value = $userList.Value + "`n"
                                    }
                                    $noModifiedOutput=$false

                                    $userList.Value = $userList.Value + ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Disabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{
                                    
                                    #set in place for formatting output
                                    if ($noUnmodifiedOutput -eq $false){
                                        $userList.Value = $userList.Value+"`n"
                                    }  
                                    $noUnmodifiedOutput = $false

                                    $userList.Value = $userList.Value+($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already disabled: " +$_.USERNAME
                                }
                            }else{
                                if ($_.ISACTIVE -eq "FALSE"){
                                    $_.ISACTIVE = "TRUE"
                                    $answer[1]=$true#sets a flag to indicate that at least one user has been modified

                                    #set in place for formatting output
                                    if ($noModifiedOutput -eq $false){
                                        $userList.Value = $userList.Value + "`n"
                                    }
                                    $noModifiedOutput=$false

                                    $userList.Value = $userList.Value + ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Enabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{

                                    #set in place for formatting output
                                    if ($noUnmodifiedOutput -eq $false){
                                        $userList.Value = $userList.Value+"`n"
                                    }
                                    $noUnmodifiedOutput = $false

                                    $userList.Value = $userList.Value+($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already enabled: " +$_.USERNAME
                                }
                            }
                            
                        }
                   }
                }
            }
        }else{#if no user were pulled from the environment as none matched the names specified
            writeOutput ( " [modifyUsers] CSV empty as none of the downloaded users were a match for the specified name in  "+$env)
            $answer[0]=$false
            return $answer
        }
    }else{#if the CSV file doesnt exist
        writeOutput ( " [modifyUsers] modifying specified users failed for " +$env +" as "+ $Global:exportCSVPath +" doesn't exist")
        $answer[0]=$false
        return $answer
    }
    if ($userExists -eq $false -and $noModifiedOutput -eq $true -and $noUnmodifiedOutput -eq $true){
            writeOutput ( " [modifyUsers] " +$names + " do(es) not exist in " + $env )
    }
    $answer[0]=$true
    return $answer
}

<#
#Purpose: calls the export file and lets the user know if it was unsuccessful
#Params: 
#env              - the org the export file will be trying to pull from
#connectionResult - if the method isn't able to connect to the org, it stores the output for the email body
#Return:bool      - indicates if the function was able to connect to the env specified
#>
Function callUpdateEXE{
    Param($env, [ref]$connectionResult)
    writeOutput(" [updateUsers] users being updated in " +$env+".....")
    $garbage=.\update\update.bat #/C exit 1
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= " [updateUsers] connection error, couldn't update users in "+$env
        writeOutput $output
        $connectionResult.Value=($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+$output
        return $false
    }else{
        writeOutput (" [updateUsers] update complete in "+$env)
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
    Param($names)
    if (Test-Path $Global:extractionConfPath){
        $testxml=[xml] (Get-Content $Global:extractionConfPath)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.extractionSOQL"){
                $element.value = "SELECT Id, Name, isActive, username FROM User"
                for ($i = 0 ; $i -lt $names.length ; $i++){
                    if ($names -ne $names){
                        if ($i -eq 0){
                            $element.value = $element.value+" WHERE Name like '"+$names[$i]+"%'"
                        }else{
                            $element.value = $element.value+" OR Name like '"+$names[$i]+"%'"
                        }
                    }else{
                        $element.value = $element.value+" WHERE Name like '"+$names[$i]+"%'"
                    }
                }
                writeOutput (" [setupExportFile] extractionSOQL set to "+ $element.value)
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($Global:extractionConfPath))
        return $true
    }else{
        writeOutput (" [setupExportFile] setting extractionSOQL failed as "+$Global:extractionConfPath+ " doesn't exist")
        return $false
    }
}

<#
#Purpose: to parse the commands extracted from the file specified with the f parameter
#Params: 
#line        - the line from the file that will be parsed
#name        - the variable that will contain the name from the line
#enable      - the variable that will specify if the user is being enable or disabled
#returnEmail - the variable that will contain any emails that the outputs will be sent to
#>
Function parseCommand{
    Param($line, [ref]$name ,[ref]$enable, [ref]$returnEmail)
    [string]$extractedName=""
    $extractedActiveFlag=$false
    $extractedEmails=@()
    if ($line.IndexOf(",") -eq -1){
        $extractedName= $line.Replace("`"", "").Trim()
        $extractedName= $extractedName.Replace("`'", "").Trim()
    }else{
        $lineInArray = $line.Split(",;").Trim()
        foreach ($_ in $lineInArray){
            [string]$part=$_
            $part=$part.Replace("`"", "").Trim()
            $part=$part.Replace("`'", "").Trim()
            if ($part.IndexOf("@") -ne -1){
                $extractedEmails+=$part
            }elseif($part -eq "enable"){
                $extractedActiveFlag=$true
            }elseif ($part -eq "disable"){
                $extractedActiveFlag=$false
            }else{
                $extractedName=$part
            }
        }
    }
    writeOutput " [modifySFUser] Parsed Command: "
    if (isValidString($extractedName)){
        writeOutput (" [modifySFUser] `tName: " + [string]::Join(",", $extractedName))
    }else{
        writeOutput " [parseCommand] No name extracted"
        return
    }

    writeOutput (" [modifySFUser] `tIsActive flag: " +$extractedActiveFlag)
    $name.Value = $extractedName
    $enable.Value = $extractedActiveFlag  
       if (isValidString($extractedEmails)){
            writeOutput (" [modifySFUser] `tRecipient emails: " + [string]::Join(",", $extractedEmails))
            $returnEmail.Value= [string]::Join(",", $extractedEmails)
    }
}

<#
#Purpose: to run through the methods needed to extract, moodify and update any users in a specific org
#Params: 
#name                  - the name(s) of the user(s) that will be modified
#env                   - the name of the org
#enable                - whether or not the user(s) will be enbled or disabled
#emailEnvList          - the variable containing the list of orgs that the script has been unable to connect to so far
#emailuserModifiedList - the variable containing the list of users that the script has successfully been able to modify
#>
Function mainMethod{
    Param($name,$env, $enable, [ref]$emailEnvList, [ref]$emailUserList)
    [string]$userList=""
    [string]$connectionResult=""
    rm $Global:updateCSVPath -ErrorAction SilentlyContinue
    rm $Global:exportCSVPath -ErrorAction SilentlyContinue

    $success=setEnvironment $Global:extractionConfPath $env
    if ($success -eq $true){#extraction environment set to env
        writeOutput (" [modifySFUser] extraction username pointing to "+$env)
        $success=callExportEXE $env ([ref]$connectionResult)
    }else{#not able to set extraction environment to env
        writeOutput (" [modifyConfigForExport] modification of extraction environment failed as ("+$Global:extractionConfPath+ ") doesn't exist")
        exit 1
    }

    $usersModified=$false
    #$success=callExportEXE $env ([ref]$connectionResult)
    if ($success -eq $true){#CSV user list successfully downloaded
            $success=modifyUsers $env $enable $name ([ref]$userList)
            if ($success[0] -eq $false){#if either the CSV was empty or it doesn't exist
                return
            }
            if ($success[1] -eq $true){#sets the flag to let the next elseif statement know that none of the users were modified
                $usersModified = $true
            }
    }else{#could not connect to the environment to download CSV user list
        $emailEnvList.Value = $emailEnvList.Value +"`n"+$connectionResult
        return
    }

    #$success=modifyUsers $env $enable $name ([ref]$userModifiedList) ([ref]$userNotModifiedList)
    if ($usersModified -eq $false){# if none of the downloaded users were modifiedE
        if ( isValidString $userList){#prints out the list of users that were not modified
            $emailUserList.Value = $emailUserList.Value + "`n"+$userList
            writeOutputWithStamp $userList
        }
        return
    }

    [string]$resultOfUpload=""
    $success=setEnvironment $Global:updateConfPath $env
    if ($success -eq $true){#update environment set to env
        writeOutput (" [modifySFUser] username for upload pointing to "+$env)
        $success = callUpdateEXE $env ([ref]$resultOfUpload)
    }else{#not able to set update environment to env
        writeOutput (" [modifyConfigForExport] modification of updating environment failed as ("+$Global:updateConfPath + ") doesn't exist")
        exit 1
    }

    #$success = callUpdateEXE $org $logPath
    if ( isValidString $userList){#prints out the list of users that were not modified
        $emailUserList.Value = $emailUserList.Value + "`n"+$userList
        writeOutputWithStamp $userList
    }
    if ( isvalidString $resultOfUpload){
        $emailEnvList.Value = $emailEnvList.Value +"`n"+$resultOfUpload
    }
}

<#
#Purpose: to run through the list of methods needed to be called if the f parameter was called
#Params: 
#emails - the array containing all the orgs that the users specified with the f parameter will be disabled in 
#Return:
#>
Function FParameterInvoked{
    Param($orgs)
        if (Test-Path $PWD\$Global:outfile){
        if ( (@(Get-Content $Global:outfile).Length -gt 0)){
            $file = Get-Content $Global:outfile
            $names=@()
            $name=""
            $enables=@()
            $enable=$false
            $emails=@()
            [string]$returnEmail=""
            foreach ($_ in $file){
                parseCommand $_ ([ref]$name) ([ref]$enable) ([ref]$returnEmail)
                $names+=$name
                $enables+=$enable
                $emails+=$returnEmail
                $returnEmail=""
   
            }
            [string]$envList=""
            [string]$userList=""
                for ($i = 0 ; $i -lt $names.Count; $i++){
                    $success=setExtractionSOQL $names[$i]
                    if ($success -ne $false){
                        writeOutput( " [FParameterInvoked] Modifying accounts for "+ $names[$i])
                        foreach($env in $orgs){
                            mainMethod $names[$i] $env $enables[$i] ([ref]$envList) ([ref]$userList)
                        }
                        sendEmail $envList $userList $emails[$i] $names[$i]
                        $envList=""
                        $userList=""
                    }
                }
        }
    }
}

<#
#Purpose: to send an email
#Params: 
#envList   - the results of environments that the script wasn't able to connect to
#userList  - the results of users that the script was able to modify
#email     - the additonal emails the the method has to include in the recipients
#name      - the user that this iteration was modifying
#>
Function sendEmail{
    Param($envList, $userList, $email, $name)
    $From = "sfpsi@cloudtest.rbaenv.com"
    $Subject = "Account Modification in Salesforce for " + $name
    $Body=""
    if ($userList.count -eq 0){
        if ($envList.count -eq 0 ){
            $Body= "This email was autogenerated from modifySFUser" 
        }else{
            $Body= $envList;
        }
    }else{
       $Body= $userList
        if ($envList.count -gt 0){
            $Body= $Body+"`n"+$envList;
        }
    }
    $finalEmailList=@()
    $finalEmailList+="sfpsi@cloudtest.rbaenv.com"
    $emailList= $email.replace(' ','').split(',')
    #$emailList+="sfpsi@cloudtest.rbaenv.com"
    foreach($_ in $emailList){
        if (isValidString $_){
            $finalEmailList+=$_
        }
    }
    $SMTPServer = "rbsinf1.qasalesite.rbauction.net"
    $SMTPPort = "25"
    #Add-Content -Path $Subject -Value $Body -Force
    if (Test-Path $logPath){
        Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments "$logPath"
    }else{
        Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort
    }
}

clear
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
        New-Item alreadyRunning.tmp -ItemType directory
    }

    #if ($args.count -eq 0 -or  $args -match "-?" -or $args -match "-help"-or $args -match "-h"){#checks to see if the script was called with no arguements, /? or /help
    #    clear
    #    Get-Content HELP_ME.txt
    #    cat HELP_ME.txt  > $logPath
    #    exit 1
    #}

    $names=@()
    $activeFlag=$false
    $emails=@()
    $org=@()
    getArgs $args  ([ref]$names) ([ref]$activeFlag) ([ref]$emails) ([ref]$org)
    $emailUserList=""
    $emailEnvList=""

    if ($names.Count -eq 0){#-f Parameter was used
        FParameterInvoked $org
    }else{#-f Parameter was not used
        $success=setExtractionSOQL $names
        if ($success -ne $false){
            foreach($env in $org){
                mainMethod $names $env $activeFlag ([ref]$emailEnvList) ([ref]$emailUserList)
            }
        }
    }
}finally{
    if ($names.Count -ne 0){
        $From = "sfpsi@cloudtest.rbaenv.com"
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
        $Body+="`n"
        $finalEmailList=@()
        foreach($_ in $emails){
            if (![string]::IsNullOrEmpty($_)){
                $finalEmailList+=$_
            }
        }
        $finalEmailList+="sfpsi@cloudtest.rbaenv.com"
        $SMTPServer = "rbsinf1.qasalesite.rbauction.net"
        $SMTPPort = "25"

        if (Test-Path $logPath){
            Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments "$logPath"
        }else{
            Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort
        }
    }

    if ($alreadyRunning -eq $false){
        #rm alreadyRunning.tmp
        rm UserList.txt -ErrorAction SilentlyContinue
    }
}