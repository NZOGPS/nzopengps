$^I = "~";
while (<>){
	print unless /CodePage/i or /LblCoding/i;
}