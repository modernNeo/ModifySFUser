<#
##Name: Jason Saadatmand
##Program Name: modify SalesForce User
##Objective: Automate Process of enabling or disabling any user in any specified SalesForce organizations
##Last Update: April 29, 2015
#>

[system.string]$Global:extractionConfPath=[system.string]$PWD+"\Data Loader\cliq_process\export\config\process-conf.xml"
[system.string]$Global:logPath=[System.String]$PWD+"\logs\"+[System.String]$(get-date -f yyyy-MM-dd)+"-"+[System.String]$(get-date -f HH-mm-ss)+".log"
[system.string]$Global:alreadyRunningPath= [system.string]$PWD+"\alreadyRunning.tmp"
[system.string]$Global:exportCSVPath=[system.string]$PWD+"\Data Loader\cliq_process\export\write\export.csv"
[System.String]$Global:updateCSVPath=[System.String]$PWD+"\Data Loader\cliq_process\update\read\update.csv"
[system.string]$Global:exportEXEPath=[system.string]$PWD+"\Data Loader\cliq_process\export\export.bat"
[System.String]$Global:updateEXEPath=[System.String]$PWD+"\Data Loader\cliq_process\update\update.bat"

[system.string]$Global:updateConfPath=[system.string]$PWD+"\Data Loader\cliq_process\update\config\process-conf.xml"
[system.string]$Global:nameOfOrgFile="C:\ModifySFUser\Sandboxes\SandboxesW.txt"
[system.string]$Global:outfile= [system.string]$PWD+"\userList.txt"
[system.string]$Global:helpFilePath= [system.string]$PWD+"\HELP_ME.txt"

<#
#Purpose: to add a stamp to the given string  and write it to the command line and to the log
#output 	-the string that has to be outputted
#>
Function writeOutput{
    Param($output)
    if (!$output.StartsWith(($(get-date -f yyyy-MM-dd)))){
        $output = ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ $output
    }
    Write-Host $output
    Add-Content -Path $logPath -Value $output -Force
}
<#
#Purpose: to test to see if the given string is valid (has actual characters) or is invalid (is empty or null or just has blank spaces
#Params: 
#theString	-the string that will be tested
#Return		-true if the string is valid and false if it is not
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
#arguments		-the command line arguments that the function will be parsing through
#names			-the array that will contains any name(s) pulled from the command line
#activeFlag		-the variable that will indicate if the users are being enabled or disabled
#emails			-the array that will contain any email address(es) pulled from the command line
#org			-the array that will contain any org(s) pulled from the command line
#>
Function getArgs{
    Param($arguments, [ref]$names,[ref]$activeFlag, [ref]$emails, [ref]$org)
    $inputName=""
    $name=$false
    $orgFlag=$false
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
        if ($orgFlag -eq $true){#extracts the orgironment(s)
            $orgList=$arg.ToString()
            $orgFlag=$false
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
            if ( Test-Path $arg.ToString()){
                cd $arg.ToString()
                $files= Get-ChildItem
                for ($i=0; $i -lt $files.Count; $i++) {
                    if ($files[$i] -match '.txt$' -or $files[$i] -match '.csv$'){
                        Get-Content $files[$i].FullName |  Out-File -Append $outfile
                        mv $files[$i].FullName ..\Done\
                    }
                }
                cd ../
                continue
            }else{
                writeOutput ( " [getArgs] error: "+ $arg.ToString() +" does not exist")
                exit 1
            }
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
            $orgFlag=$true
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
    if ($fileParameterSet -eq $true){#if the script was instructed to read the names and enable parameter from a folder contents
        if (Test-Path $Global:nameOfOrgFile) {#pulling orgs from file
            writeOutput ( " [getArgs] orgs extracted from " +$Global:nameOfOrgFile+ " file for -f parameter")
            $orgNames = (Get-Content $Global:nameOfOrgFile)
			foreach($_ in $orgNames){
				if (isValidString $_){
					$org.Value+=$_
				}
			}
            return
        }else{#file containing orgs not found
            writeOutput ( " [getArgs] " + $Global:nameOfOrgFile +" file not found for -f parameter" )
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
    if ( !isValidString $inputName) {#if no names were entered    
        writeOutput " [getArgs] No Names specified"
        exit 1  
    }

    writeOutput (" [getArgs] Params: -n: "+$inputName)
    foreach ($_ in $inputName.Split(",;").Trim()){
        $names.Value+=$_
    }




    #testing the orgs specified to make sure that either there were entries or the backup textfile is accessible
    if (isValidString $orgList){
        writeOutput ( " [getArgs] Params: -org: "+$orgList )
        $org.Value= @($orgList.Split(",;").Trim()) | foreach{$_}
    }else{
       if (Test-Path $Global:nameOfOrgFile) {#no orgs were specified and resorted to pulling orgs from file
            writeOutput ( " [getArgs] No Orgs Specified, orgs extracted from "+$Global:nameOfOrgFile+ " file" )
            $orgNames = (Get-Content $Global:nameOfOrgFile)
            $org.Value= @($orgNames) | foreach{$_}
        }else{#orgs werent specified and file containing orgs not found
        Write-Host "2adsadsf"
            writeOutput ( " [getArgs] No Orgs Specified and "+$Global:nameOfOrgFile+ " file not found" )
            exit 1
        }
    }
}
<#
#Purpose: to set the process-conf to pull from the correct org
#Params: 
#pathName		-the pathname for the config file
#org			-the org to pull from
#Return: bool	-indicates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setOrganization{
    Param($pathName, $org)
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
#Params: 
#org				-the org the export file will be trying to pull from
#connectionResult	-if the method isn't able to connect to the org, it stores the output for the email body
#Return				-true if the function executed properly to let the main know its safe to keep going or false if the script has to be terminated early due to a bug
#>
Function callExportEXE{
    Param($org, [ref]$connectionResult)
    writeOutput ( " [callExportEXE] connecting to "+$org+ "......" )
    & $Global:exportEXEPath
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output=" [callExportEXE] Unable to connect to org "+$org
        writeOutput $output
        $connectionResult.Value = ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+$output
        return $false
    }
    writeOutput ( " [callExportEXE] connected to "+$org +" and user list extracted")
    return $true
}
<#
#Purpose: to enable or disable all the users in the user list
#Params: 
#org					- the organization that the method is currently modfiying users in
#enable					- the flag that determines whether the function is currently enabling or disabling users
#names					- the names of all the users that the function has to modifying the in specified organization
#userList				- the string containing the results of all the modified and unmodified user
#Return: 3d array		- first index indicates whether the CSV wasn't found or was empty
#						- second index indicates whether or not any users were actually modified
#						- third index indicates if none of the users actually exist in the environment
#>
Function modifyUsers{
    Param($org, $enable, $names, [ref]$userList)
    $answer=@(@(),@(),@())
    $answer[1]=$false
	$answer[2]=$false
    $noOutput=$true
    $noUsersDownloaded=$true
    $nousersMatch=$true
    $CSVempty=$true
    if (Test-Path $Global:exportCSVPath){#tests to make sure the CSV file exists
       $CSVempty=$false
        if ( (@(Get-Content $Global:exportCSVPath).Length) -gt 1){#tests to see if the file does even have any users before bothering to read it
            ($csv = Import-Csv $Global:exportCSVPath -Delimiter ',' )|
            foreach{
            $noUsersDownloaded=$false
                if ($_.NAME.IndexOf("(") -ne -1) { #Normalize the target name (get rid of any bracketed info)
                    $parsedName = $_.NAME.Substring(0,$_.NAME.IndexOf("(")).trim()
                } else {
                    $parsedName = $_.NAME.trim()
                }
                $parsedUserName = $_.USERNAME.Substring(0,$_.USERNAME.IndexOf("@")).trim()
                foreach($name in $names){#runs through the names the user specified\
					
                    if ($name -match $parsedName){#to make sure the name on the list is an exact match before attempting to modify it
						$nousersMatch=$false
                        if ( !( $parsedUserName -match '^sfdcadmin[0-9]$'  -or #sfdcadmin5@rbauction.com.test01f should not be disabled
                        $parsedUserName -match '^csf-*'  ) ){#and it makes sure that the user doesnt start with csf-        
                
                            if ($enable -eq $false){#tests to see if the user had wanted to disable or enable the specified accounts
                
                                if ($_.ISACTIVE -eq "TRUE"){
                                    $_.ISACTIVE = "FALSE"
                                    $answer[1]=$true#sets a flag to indicate that at least one user has been modified
                                    
                                    #set in place for formatting output
                                    if ($noOutput -eq $false){
                                        $userList.Value = $userList.Value + "`n"
                                    }
                                    $noOutput=$false

                                    $userList.Value = $userList.Value + ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Disabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{
                                    
                                    #set in place for formatting output
                                    if ($noOutput -eq $false){
                                        $userList.Value = $userList.Value+"`n"
                                    }  
                                    $noOutput = $false

                                    $userList.Value = $userList.Value+($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already disabled: " +$_.USERNAME
                                }
                            }else{
                                if ($_.ISACTIVE -eq "FALSE"){
                                    $_.ISACTIVE = "TRUE"
                                    $answer[1]=$true#sets a flag to indicate that at least one user has been modified

                                    #set in place for formatting output
                                    if ($noOutput -eq $false){
                                        $userList.Value = $userList.Value + "`n"
                                    }
                                    $noOutput=$false

                                    $userList.Value = $userList.Value + ($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Enabled: " +$_.USERNAME
                                    $_ | select ID , ISACTIVE | Export-Csv -Append $Global:updateCSVPath -Delimiter ',' -NoType
                                }else{

                                    #set in place for formatting output
                                    if ($noOutput -eq $false){
                                        $userList.Value = $userList.Value+"`n"
                                    }
                                    $noOutput = $false

                                    $userList.Value = $userList.Value+($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] Already enabled: " +$_.USERNAME
                                }
                            }
                            
                        }
                   }
                }
            }
        }
    }else{#if the CSV file doesnt exist
        [string]$output=(($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] modifying specified users failed for " +$org +" as the exportCSV doesn't exist")
        writeOutput $output
        $userList.Value = $userList.Value+$output
        $answer[0]=$false
        return $answer
    }
    if ($noUsersDownloaded -eq $true){#if CSV is empyu
        [string]$output=(($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] modifying specified users " + $names + " failed for " +$org +" as the exportCSV was empty")
        writeOutput $output
        $userList.Value = $userList.Value+$output
        $answer[0]=$false
        return $answer
    }
    elseif ($nousersMatch -eq $true -and $noOutput -eq $true){#if none of the downloaded names were a match
        [string]$output=(($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+ " [modifyUsers] modifying specified users failed for " +$org +" as "+$names + " do(es) not exist in " + $org )
        writeOutput $output
        $userList.Value = $userList.Value+$output
        $answer[0]=$false
        return $answer
    }
    $answer[0]=$true
    return $answer
}
<#
#Purpose: calls the update file and lets the user know if it was unsuccessful
#Params: 
#org				- the org the update file will be trying to update to
#connectionResult	- if the method isn't able to connect to the org, it stores the output for the email body
#Return:bool		- indicates if the function was able to connect to the org specified
#>
Function callUpdateEXE{
    Param($org, [ref]$connectionResult)
    writeOutput(" [callUpdateEXE] users being updated in " +$org+".....")
    & $Global:updateEXEPath 
    if ($LASTEXITCODE -ne 0 ){
        [system.String]$output= " [callUpdateEXE] connection error, couldn't update users in "+$org
        writeOutput $output
        $connectionResult.Value=($(get-date -f yyyy-MM-dd)+" "+$(get-date -f HH:mm:ss))+$output
        return $false
    }else{
        writeOutput (" [callUpdateEXE] update complete in "+$org)
        return $true
    }
}
<#
#Purpose: to set the SOQl in the extract config file to extract the correct users from the org
#Params:
#names			- the array with all the names that the script has been asked to modify 
#Return: bool	- indicates if the function executed properly to let the main know its safe to keep going or if the script has to be terminated early due to a bug
#>
Function setExtractionSOQL{
    Param($names)
    if (Test-Path $Global:extractionConfPath){
        $testxml=[xml] (Get-Content $Global:extractionConfPath)
        foreach ($element in $testxml.beans.bean.property.map.entry){
            if ($element.key -eq "sfdc.extractionSOQL"){
                $element.value = "SELECT Id, Name, isActive, username FROM User"
                if ($names -is [system.array] -and $names.Count -gt 0){
	                for ($i = 0 ; $i -lt $names.length ; $i++){
                        if ($i -eq 0){
                            $element.value = $element.value+" WHERE Name like '"+$names[$i]+"%'"
                        }else{
                            $element.value = $element.value+" OR Name like '"+$names[$i]+"%'"
                        }
	                }
				}else{
                        $element.value = $element.value+" WHERE Name like '"+$names+"%'"
                }
                writeOutput (" [setExtractionSOQL] extractionSOQL set to "+ $element.value)
            }
        }
        $testxml.Save([System.IO.Path]::GetFullPath($Global:extractionConfPath))
        return $true
    }else{
        writeOutput (" [setExtractionSOQL] setting extractionSOQL failed as "+$Global:extractionConfPath+ " doesn't exist")
        return $false
    }
}
<#
#Purpose: to parse the commands extracted from the file specified with the f parameter
#Params: 
#line			- the line from the file that will be parsed
#name			- the variable that will contain the name from the line
#enable			- the variable that will specify if the user is being enable or disabled
#returnEmail	- the variable that will contain any emails that the outputs will be sent to
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
    writeOutput " [parseCommand] Parsed Command: "
    if (isValidString($extractedName)){
        writeOutput (" [parseCommand] `tName: " + [string]::Join(",", $extractedName))
    }else{
        writeOutput " [parseCommand] No name extracted"
        return
    }

    writeOutput (" [parseCommand] `tIsActive flag: " +$extractedActiveFlag)
    $name.Value = $extractedName
    $enable.Value = $extractedActiveFlag  
       if (isValidString($extractedEmails)){
            writeOutput (" [modifySFUser] `tRecipient emails: " + [string]::Join(",", $extractedEmails))
            $returnEmail.Value= [string]::Join(",", $extractedEmails)
    }
}
<#
#Purpose: to run through the methods needed to extract, modify and update any users in a specific org
#Params: 
#name					- the name(s) of the user(s) that will be modified
#org					- the name of the org
#enable					- whether or not the user(s) will be enbled or disabled
#emailOrgList			- the variable containing the list of orgs that the script has been unable to connect to so far
#$emailUserList			- the variable containing the list of users that the script had to deal with
#>
Function mainMethod{
    Param($name,$org, $enable, [ref]$emailOrgList, [ref]$emailUserList)
    [string]$userList=""
    [string]$connectionResult=""
    rm $Global:updateCSVPath -ErrorAction SilentlyContinue
    rm $Global:exportCSVPath -ErrorAction SilentlyContinue

    $success=setOrganization $Global:extractionConfPath $org
    if ($success -eq $true){#extraction organization set to org
        writeOutput (" [mainMethod] extraction username pointing to "+$org)
        $success=callExportEXE $org ([ref]$connectionResult)
    }else{#not able to set extraction organzation to org
        writeOutput (" [mainMethod] modification of extraction organization failed as ("+$Global:extractionConfPath+ ") doesn't exist")
        exit 1
    }

    $usersModified=$false
    #$success=callExportEXE $org ([ref]$connectionResult)
    if ($success -eq $true){#CSV user list successfully downloaded
            $success=modifyUsers $org $enable $name ([ref]$userList)
            if ($success[0] -eq $false){#if either the CSV was empty or it doesn't exist
                $emailUserList.Value=$emailUserList.Value+"`n"+$userList
                return
            }
            if ($success[1] -eq $true){#sets the flag to let the next elseif statement know that none of the users were modified
                $usersModified = $true
            }
    }else{#could not connect to the organzation to download CSV user list
        $emailOrgList.Value = $emailOrgList.Value +"`n"+$connectionResult
        return
    }

    #$success=modifyUsers $org $enable $name ([ref]$userModifiedList) ([ref]$userNotModifiedList)
    if ($usersModified -eq $false){# if none of the downloaded users were modifiedE
        if ( isValidString $userList){#prints out the list of users that were not modified
            $emailUserList.Value = $emailUserList.Value + "`n"+$userList
            writeOutput $userList
        }
        return
    }

    [string]$resultOfUpload=""
    $success=setOrganization $Global:updateConfPath $org
    if ($success -eq $true){#update organization set to org
        writeOutput (" [mainMethod] username for upload pointing to "+$org)
        $success = callUpdateEXE $org ([ref]$resultOfUpload)
    }else{#not able to set update organization to org
        writeOutput (" [mainMethod] modification of updating organization failed as ("+$Global:updateConfPath + ") doesn't exist")
        exit 1
    }

    #$success = callUpdateEXE $org $logPath

    if ( $success -eq $true -and ( isValidString $userList ) ){#prints out the list of users that were not modified
        $emailUserList.Value = $emailUserList.Value + "`n"+$userList
        writeOutput $userList
    }elseif ( isvalidString $resultOfUpload){
        $emailOrgList.Value = $emailOrgList.Value +"`n"+$resultOfUpload
    }
}
<#
#Purpose: to run through the list of methods needed to be called if the f parameter was called
#Params: 
#emails		- the array containing all the orgs that the users specified with the f parameter will be disabled in 
#>
Function fParameterInvoked{
    Param($orgs)
        if (Test-Path $Global:outfile){
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
   				$name=""
				$enable=""
            }
            [string]$orgList=""
            [string]$userList=""
                for ($i = 0 ; $i -lt $names.Count; $i++){
                    $success=setExtractionSOQL $names[$i]
                    if ($success -ne $false){
                        writeOutput( " [fParameterInvoked] Modifying accounts for "+ $names[$i])
                        foreach($org in $orgs){
                            mainMethod $names[$i] $org $enables[$i] ([ref]$orgList) ([ref]$userList)
                        }
                        sendEmail $orgList $userList $emails[$i] $names[$i]
                        $orgList=""
                        $userList=""
                    }
                }
        }
    }
}
<#
#Purpose: to send an email
#Params: 
#orgList	- the results of organzations that the script wasn't able to connect to
#userList	- the results of users that the script was able to modify
#email		- the additonal emails the the method has to include in the recipients
#name		- the user that this iteration was modifying
#>
Function sendEmail{
    Param($orgList, $userList, $email, $name)
    $From = "sfpsi@rbauction.com"
    $Subject = "Account Modification in Salesforce for " + $name
    $Body=""
    if ($userList.count -eq 0){
        if ($orgList.count -eq 0 ){
            $Body= "This email was autogenerated from modifySFUser" 
        }else{
            $Body= $orgList;
        }
    }else{
       $Body= $userList
        if ($orgList.count -gt 0){
            $Body= $Body+"`n"+$orgList;
        }
    }
    $finalEmailList=@()
    $finalEmailList+="sfpsi@rbauction.com"
    $emailList= $email.replace(' ','').split(',')
    foreach($_ in $emailList){
        if (isValidString $_){
            $finalEmailList+=$_
        }
    }
    $SMTPServer = "rbsinf1.qasalesite.rbauction.net"
    $SMTPPort = "25"
    if (Test-Path $logPath){
        Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments "$logPath"
    }else{
        Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort
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
         $garbage=New-Item $Global:alreadyRunningPath -ItemType File
    }

    if ($args.count -eq 0 -or  $args[0] -match "-help"-or $args[0] -match "-h"){#checks to see if the script was called with no arguements, /? or /help
        clear
        Get-Content $Global:helpFilePath
        cat $Global:helpFilePath  > $logPath
        exit 1
    }
    
    $names=@()
    $activeFlag=$false
    $emails=@()
    $orgs=@()
    getArgs $args  ([ref]$names) ([ref]$activeFlag) ([ref]$emails) ([ref]$orgs)
    $emailUserList=""
    $emailorgList=""
    if ($names.Count -eq 0){#-f Parameter was used

        fParameterInvoked $orgs
    }else{#-f Parameter was not used
        $success=setExtractionSOQL $names
        if ($success -ne $false){
            foreach($org in $orgs){
                mainMethod $names $org $activeFlag ([ref]$emailorgList) ([ref]$emailUserList)
            }
        }
    }
}finally{
    if ($names.Count -ne 0){
        $From = "sfpsi@rbauction.com"
        $Subject = "Account Modification in Salesforce"
        $Body=""
        if ( !isValidString $emailUserList){
            if ( !isValidString  $emailorgList){
                $Body+= "This email was autogenerated from modifySFUser" 
            }else{
                $Body+=$emailorgList;
            }
        }else{
            $Body+= $emailUserList
            if ( isValidString $emailorgList ){
                $Body+="`n"+$emailorgList;
            }
        }
        $Body+="`n"
        $finalEmailList=@()
        foreach($_ in $emails){
            if ( isValidString $_ ){
                $finalEmailList+=$_
            }
        }
        $finalEmailList+="sfpsi@rbauction.com"
        $SMTPServer = "rbsinf1.qasalesite.rbauction.net"
        $SMTPPort = "25"

        if (Test-Path $logPath){
            Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments "$logPath"
        }else{
            Send-MailMessage -From $From -to $finalEmailList -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort
        }
    }
    if ($alreadyRunning -eq $false){
        rm $Global:alreadyRunningPath
        rm $Global:outfile -ErrorAction SilentlyContinue
    }
}