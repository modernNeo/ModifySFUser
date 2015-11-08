<?php
if($_POST['formSubmit'] == "Submit")
{
	error_reporting (E_ALL);
	$errorMessage = "";
	

	if(empty($_POST['formName']))
	{
		$errorMessage .= "<li>Missing name</li>";
	}
	
	$varName = $_POST['formName'];
	$varActiveFlag = $_POST['formActiveFlag'];
	$varAddEmails = $_POST['formAddEmails'];

	if(empty($errorMessage)) 
	{
		$sTriggerLine = "";
		$sTriggerLine .= $varName;
		
		if (!empty($_POST['formActiveFlag'])){
			$sTriggerLine .=  ", " . $varActiveFlag;
		}
		
		if (!empty($_POST['formAddEmails'])){
			$sTriggerLine .= "," . $varAddEmails;
		}
		
		date_default_timezone_set('America/Los_Angeles');
		$timestamp = date("M j Y , h i s A T");
		$fileName = "Trigger/$timestamp.txt";
				
		$fs = fopen($fileName,"w");
		fwrite($fs,$sTriggerLine);
		fclose($fs);

		header("Location: thanks.php?sbx=" );
		exit;
	}
}
?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"> 
<html>
<head>
<title>Modifying Users on Salesforce</title>
<link rel="shortcut icon" href="favicon.ico">
<style>
body { font-family: Arial, Helvetica, sans-serif; }
label { display: block; width: 10em; float: left; }
.required {color: #FF0000; margin-left: 20px; }
.error {color: #FF0000; background: lightyellow; border: solid 1px red; margin: 5px; padding: 5px; width: 40em; }
.smallitalic {font-size: 0.9em; font-style: italic; }
.fieldset-auto-width { display: inline-block; margin: 5px; }
</style>
</head>

<body>
<h2>Modifying Users on Salesforce</h2>
<p><span class="required">* = required fields</span></p>

	<?php
		if(!empty($errorMessage)) 
		{
			echo("<div class=\"error\">");
			echo("<strong>Error: </strong>Correct the errors below and resubmit.&nbsp;&nbsp;Or, <a href=\"index.php\">reset the form</a>.\n");
			echo("<ul>" . $errorMessage . "</ul>\n");
			echo("</div>");
		}
	?>

	<form action="index.php" method="post">

<fieldset class="fieldset-auto-width">
<legend>Commands:</legend>
	<br>
	
	<div><label for="nameLabel">Users to modify:</label>
	<span class="required">*</span>
	<input type="text" id="nameLabel" name="formName" size="30"  value="<?php echo $varName;?>" />
	</div>
	<br>

	<div><label for="ActiveFlag">IsActive Flag</label>
	<span class="required">*</span>
	<input type="radio" id="enableFlag" name="formActiveFlag" value="enable" /> Enable
	&nbsp;&nbsp;&nbsp;
	<input type="radio" id="disableFlag" name="formActiveFlag" CHECKED value="disable" /> Disable
	</div>
	<br>
	
	<div><label for="addEmails">Confirmation Emails:</label>
	<input type="text" id="addEmails" name="formAddEmails" size="35" value="<?php echo $varAddEmails;?>" />
	</div>
	<br>
</fieldset>

	<p style="margin-left: 80px;">
	
	<input type="submit" name="formSubmit" value="Submit" />
	</form>
	</p>

	</body>
</html>
