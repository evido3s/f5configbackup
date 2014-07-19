<?php
$title = "Delete Device";

# Make device array
$sth = $dbh->query("SELECT NAME,ID FROM DEVICES ORDER BY NAME");
$sth->execute();		
foreach ($sth->fetchAll() as $dev) {
	$devarray[$dev['ID']] = $dev['NAME'];
};

// Is method POST ?
if ($_SERVER['REQUEST_METHOD'] == "POST") {
// Delete from DB
	// If cancel button is clicked
	if ($_POST["confirm"] == "Cancel") {
		$location = "https://".$_SERVER['HTTP_HOST']."/devices.php";
		header("Location: $location");
		die();		
	} else {
		// If not then loop though IDs
		$contents .= "\t<p>Devices have been removed. </p>\n\t<ul>\n";
		foreach ($_POST["id"] as $i) {
			// Is input numeric ?
			if (is_numeric($i)) {
				//Delete from DB
				$sth = $dbh->prepare("DELETE FROM DEVICES WHERE ID = ?");
				$sth->bindValue(1,$i); 
				$sth->execute();			
			
				// Add to list on page
				$dev = $devarray[$i];
				$contents .= "\t\t<li>$dev\n";
			};
		};
	$contents .= "\t</ul>";
	};
} else {
//If not post then display confirmation page
	// Check if any devices are selected
	if (isset($_GET["id"])) {
		$inputs = '';
		$contents .= "\t<p>Are you sure you want to delete the following devices ?</p>\n\t<ul>\n";
			// Loop though array of params
			foreach ($_GET["id"] as $i) {
			if (is_numeric($i)) {
				$dev = $devarray[$i];
				$contents .= "\t\t<li>$dev\n";
				//Create hidden input html
				$inputs .= "\t\t<input type=\"hidden\" name=\"id[]\" value=\"$i\">\n";
			};
		};
		$contents .= "\t</ul>\n\t<form action=\"devices.php?page=Delete\" method=\"post\">\n";
		$contents .= $inputs;	
		$contents .= "\t<input type=\"submit\" name=\"confirm\" value=\"Yes\">\n";
		$contents .= "\t<input type=\"submit\" name=\"confirm\" value=\"Cancel\">\n\t</form>\n";
	} else {
	// If not then display error message
		$contents .= "<p>No devices selected.</p>";
	};
};

?>