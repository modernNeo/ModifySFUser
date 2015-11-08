<?php
//confirm page was submitted from index.php, otherwise redirect
if(isset($_REQUEST['sbx']))
{
	$varSandbox = $_REQUEST['sbx'];
} else {
	header("Location: index.php");
}
?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"> 
<html>
<head>
<title>Modifying Users on Salesforce</title>
<style>
.smallitalic {font-size: 0.9em; font-style: italic; }
h3 {color: #0000FF; font-size: 1.1em; font-style: italic; }
body { font-family: Arial, Helvetica, sans-serif; }
</style>
</head>

<body>
<h2>Salesforce Script Trigger Results</h2>
<h3>trigger file was created for modifySFUser script</h3>

<ul>
<li>Check Trigger files in the <a href="Trigger">Trigger folder</a></li>
<li>Check progress modified users in the <a href="logs">log folder</a></li>

<li>Or <a href="index.php">return to the form</a></li>
</ul>

<img src="fireworks.gif">

</body>
</html>
