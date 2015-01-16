$^I = "~";
while (<>){
	print unless /CodePage/ or /LblCoding/;
}