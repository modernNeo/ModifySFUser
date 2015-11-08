Hello There.

Welcome to my very first (and quite remarkable if I may say so) powershell script. If you dont have any experience in Powershell, don't worry. I had no experience in it either until I started working on that script. My previous commandline experience was using linux and my Mac. If there is anything you can't seem to figure out either from debugging continously and turning to the trusty Google, Michael Casinha is known as the in-house Powershell Master. He helped me get started also, send him an email or a lync with your question and he'll be able to answer them.

Using my script is rather basic. I know how frustrating an un-unintuitive script can be, I myself find the man pages for cmdlets on linux and powershell rather unhelpful and often go to Google for further clarification.

So here's how it works

There are 6 possible options you can use and one which outranks the rest

-n is used to specify the names of all the users you want to modify
used like so: -n:"Aragorn, Doctor Who; James Howlett"

you can use either the semi-colon or the comma, my script will catch both (amazing, right?)

-org and -email both follow the same syntactical idea behind -n
	-use double quotes after the colon (like so: -org: AND -email)
	-can use either a semi-colon or a comma to separate the different orgs or emails you want to use

and for the sake of a real example
	-org:"dev43, uat03f; test01f"
	-email"random_email1@rbauction.com, random_email2@rbauction.com; random_email3@rbauction.com"
	
and now heres a rule for my script. use the -n only once, use the -org only once and use the -email only once. trying to use any of the parameters 2 or more in one go and my script will self-terminate.

-disable and -email disables or enables the accounts, depending on which you use. trying to use both will always cause my script to self-terminate

-f
	if this one is used, all other parameters used (if you tried to include any others) will be completely ignored
	with this parameter, you will be specifying a folder that contains a bunch of .txt and .csv files, you can provide either an abosolute path or a relative path for this parameter.
	to get an idea of what the files should look like, refer to the HELP_ME file

*REGARDING THE SANDBOXES FILE*
if you want to change what sandbox file the script uses, change via the global variable on line 17.


If you have any questions about the functionality of the script that the help file and the above synposis couldnt answer, feel free to contact me at peyvand.manshadi@gmail.com, my name is Jason Saadatmand and I get my emails pushed to my phone so I'll answer rather quickly. Include the log and the modifySFUser script in your email as I'll probably end up needing those two things to be of assistance. Also start the subject with "modifySFUser Script Troubleshooting - ". That'll get my attention for sure.

Live Long and Prosper